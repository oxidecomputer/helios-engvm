use crate::prelude::*;
/*
 * Copyright 2024 Oxide Computer Company
 */

use std::{path::PathBuf, process::Command};

pub(crate) async fn image(mut l: Level<Stuff>) -> Result<()> {
    l.cmd("step", "individual image building steps", cmd!(step))?;

    sel!(l).run().await
}

async fn step(mut l: Level<Stuff>) -> Result<()> {
    l.cmd("strap", "build tar file with installed Helios", cmd!(strap))?;
    l.cmd("ufs", "build a UFS ramdisk image from a prior strap", cmd!(ufs))?;
    l.cmd("iso", "build an ISO/USB image from a prior UFS image", cmd!(iso))?;
    l.cmd("disk", "build a ZFS disk image from a prior strap", cmd!(disk))?;

    sel!(l).run().await
}

fn arg_or_env(
    a: &hiercmd::Arguments,
    opt: &str,
    var: &str,
    def: &str,
) -> Result<String> {
    Ok(if let Some(val) = a.opts().opt_str(opt) {
        val
    } else if let Ok(val) = std::env::var(var) {
        val
    } else {
        def.to_string()
    })
}

fn cargo_target_cmd(
    project: &str,
    command: &str,
    debug: bool,
) -> Result<String> {
    let bin = repo::top_path(&[
        "image",
        project,
        "target",
        if debug { "debug" } else { "release" },
        command,
    ])?;
    if !bin.is_file() {
        bail!("binary {bin:?} does not exist.  run \"gmake setup\"?");
    }
    Ok(bin.to_str().unwrap().to_string())
}

fn basecmd(cfg: &config::Config, group: &str, name: &str) -> Result<Command> {
    let builder = cargo_target_cmd("image-builder", "image-builder", false)?;
    let top = repo::top_path(&["image"])?;
    let templates = repo::rel_path(Some(&top), &["templates"])?;

    let mut cmd = Command::new("pfexec");
    cmd.arg(&builder);
    cmd.arg("build");
    cmd.arg("-d").arg(&cfg.dataset);
    cmd.arg("-T").arg(&templates);
    cmd.arg("-g").arg(group);
    cmd.arg("-F").arg(format!("name={name}"));

    Ok(cmd)
}

async fn strap(mut l: Level<Stuff>) -> Result<()> {
    let mut sw = StopWatch::start();

    l.optflag("f", "", "destroy any existing files and start from scratch");
    l.optopt(
        "V",
        "",
        "OS image contents variant (default: base)",
        "base|full|ramdisk",
    );
    l.optopt("F", "", "pass through extra feature flags", "NAME[=VALUE]");
    l.optopt("g", "", "override template group name", "NAME");
    l.optopt("O", "", "override template output name", "NAME");

    let a = no_args!(l);

    let full_reset = a.opts().opt_present("f");
    let extra_features = a.opts().opt_strs("F");
    let variant = arg_or_env(&a, "V", "VARIANT", "base")?;
    let group = arg_or_env(&a, "g", "GROUP", "helios")?;
    let name = arg_or_env(&a, "O", "OUTPUT_NAME", "helios-dev")?;

    let log = &l.context().log;

    let cfg = config::Config::load(log)?;

    let mut outputs = vec![repo::rel_path(
        Some(&cfg.mountpoint),
        &["output", &format!("{name}-{variant}.tar")],
    )?];
    if variant == "ramdisk" {
        outputs.push(repo::rel_path(
            Some(&cfg.mountpoint),
            &["output", &format!("{name}-{variant}-boot.tar")],
        )?);
    }

    for o in &outputs {
        maybe_unlink_as_root(o)?;
    }

    let step_pre = |n: &str| -> Result<(String, Command)> {
        let tname = format!("{variant}-{n}");
        info!(log, "image builder template: {tname}...");
        Ok((tname, basecmd(&cfg, &group, &name)?))
    };

    let mut step_post = |tname: String, mut cmd: Command| -> Result<()> {
        for f in &extra_features {
            cmd.arg("-F").arg(f);
        }
        ensure::run2(log, &mut cmd)?;
        info!(log, "{tname} complete after {} seconds", sw.lap().as_secs());
        Ok(())
    };

    let (tname, mut cmd) = step_pre("01-strap")?;
    cmd.arg("-n").arg(&tname);
    if full_reset {
        cmd.arg("--fullreset");
    }
    step_post(tname, cmd)?;

    let (tname, mut cmd) = step_pre("02-image")?;
    cmd.arg("-n").arg(&tname);
    step_post(tname, cmd)?;

    let (tname, mut cmd) = step_pre("03-archive")?;
    cmd.arg("-n").arg(&tname);
    step_post(tname, cmd)?;

    for o in &outputs {
        if !o.is_file() {
            bail!("expected output file {o:?} was not generated?");
        }
    }

    info!(
        log,
        "after {} seconds, output files: {outputs:?}",
        sw.total().as_secs()
    );

    Ok(())
}

fn setup_genproto(a: &hiercmd::Arguments) -> Result<Option<PathBuf>> {
    let protofile =
        repo::top_path(&["image", "templates", "include", "genproto.json"])?;
    maybe_unlink(&protofile)?;

    Ok(if let Some(proto) = a.opts().opt_str("P") {
        let proto = PathBuf::from(proto);
        genproto::genproto(&proto, &protofile)?;
        Some(proto)
    } else {
        None
    })
}

async fn disk(mut l: Level<Stuff>) -> Result<()> {
    let mut sw = StopWatch::start();

    l.optopt("P", "", "extra proto area to overlay for files", "DIR");
    l.optopt("m", "", "machine type (default: generic)", "MACHINE");
    l.optopt("c", "", "console type (default: ttya)", "ttya|ttyb|vga");
    l.optopt("F", "", "pass through extra feature flags", "NAME[=VALUE]");
    l.optopt("g", "", "override template group name", "NAME");
    l.optopt("O", "", "override template output name", "NAME");
    l.optopt("V", "", "OS image contents variant (default: base)", "base|full");

    let a = no_args!(l);

    let extra_features = a.opts().opt_strs("F");
    let machine = arg_or_env(&a, "m", "MACHINE", "generic")?;
    let console = arg_or_env(&a, "c", "CONSOLE", "ttya")?;
    let variant = arg_or_env(&a, "V", "VARIANT", "base")?;
    let group = arg_or_env(&a, "g", "GROUP", "helios")?;
    let name = arg_or_env(&a, "O", "OUTPUT_NAME", "helios-dev")?;

    let proto = setup_genproto(&a)?;

    let log = &l.context().log;

    let cfg = config::Config::load(log)?;

    let outputs = vec![repo::rel_path(
        Some(&cfg.mountpoint),
        &["output", &format!("{group}-{machine}-{console}-{variant}.raw")],
    )?];

    for o in &outputs {
        maybe_unlink_as_root(o)?;
    }

    let step_pre = || -> Result<(String, Command)> {
        let tname = format!("{machine}-{console}-{variant}");
        info!(log, "image builder template: {tname}...");
        Ok((tname, basecmd(&cfg, &group, &name)?))
    };

    let mut step_post = |tname: String, mut cmd: Command| -> Result<()> {
        for f in &extra_features {
            cmd.arg("-F").arg(f);
        }
        ensure::run2(log, &mut cmd)?;
        info!(log, "{tname} complete after {} seconds", sw.lap().as_secs());
        Ok(())
    };

    let (tname, mut cmd) = step_pre()?;
    cmd.arg("-n").arg(&tname);
    if let Some(proto) = &proto {
        cmd.arg("-F").arg("genproto");
        cmd.arg("-E").arg(proto);
    }
    step_post(tname, cmd)?;

    for o in &outputs {
        if !o.is_file() {
            bail!("expected output file {o:?} was not generated?");
        }
    }

    info!(
        log,
        "after {} seconds, output files: {outputs:?}",
        sw.total().as_secs()
    );

    Ok(())
}

async fn ufs(mut l: Level<Stuff>) -> Result<()> {
    let mut sw = StopWatch::start();

    l.optopt("P", "", "extra proto area to overlay for files", "DIR");
    l.optopt("m", "", "machine type (default: generic)", "MACHINE");
    l.optopt("c", "", "console type (default: ttya)", "ttya|ttyb|vga");
    l.optopt("F", "", "pass through extra feature flags", "NAME[=VALUE]");
    l.optopt("g", "", "override template group name", "NAME");
    l.optopt("O", "", "override template output name", "NAME");

    let a = no_args!(l);

    let extra_features = a.opts().opt_strs("F");
    let machine = arg_or_env(&a, "m", "MACHINE", "generic")?;
    let console = arg_or_env(&a, "c", "CONSOLE", "ttya")?;
    let variant = "ufs";
    let group = arg_or_env(&a, "g", "GROUP", "helios")?;
    let name = arg_or_env(&a, "O", "OUTPUT_NAME", "helios-dev")?;

    let proto = setup_genproto(&a)?;

    let log = &l.context().log;

    let cfg = config::Config::load(log)?;

    let outputs = vec![repo::rel_path(
        Some(&cfg.mountpoint),
        &["output", &format!("{group}-{machine}-{console}-{variant}.ufs")],
    )?];

    for o in &outputs {
        maybe_unlink_as_root(o)?;
    }

    let step_pre = || -> Result<(String, Command)> {
        let tname = format!("{machine}-{console}-{variant}");
        info!(log, "image builder template: {tname}...");
        Ok((tname, basecmd(&cfg, &group, &name)?))
    };

    let mut step_post = |tname: String, mut cmd: Command| -> Result<()> {
        for f in &extra_features {
            cmd.arg("-F").arg(f);
        }
        ensure::run2(log, &mut cmd)?;
        info!(log, "{tname} complete after {} seconds", sw.lap().as_secs());
        Ok(())
    };

    let (tname, mut cmd) = step_pre()?;
    cmd.arg("-n").arg(&tname);
    if let Some(proto) = &proto {
        cmd.arg("-F").arg("genproto");
        cmd.arg("-E").arg(proto);
    }
    step_post(tname, cmd)?;

    for o in &outputs {
        if !o.is_file() {
            bail!("expected output file {o:?} was not generated?");
        }
    }

    info!(
        log,
        "after {} seconds, output files: {outputs:?}",
        sw.total().as_secs()
    );

    Ok(())
}

async fn iso(mut l: Level<Stuff>) -> Result<()> {
    let mut sw = StopWatch::start();

    l.optflag("N", "", "do not include install archive in the ISO");
    l.optopt("m", "", "machine type (default: generic)", "MACHINE");
    l.optopt("c", "", "console type (default: ttya)", "ttya|ttyb|vga");
    l.optopt("P", "", "extra proto area to overlay for files", "DIR");
    l.optopt("F", "", "pass through extra feature flags", "NAME[=VALUE]");
    l.optopt("g", "", "override template group name", "NAME");
    l.optopt("O", "", "override template output name", "NAME");

    let a = no_args!(l);

    let extra_features = a.opts().opt_strs("F");
    let machine = arg_or_env(&a, "m", "MACHINE", "generic")?;
    let console = arg_or_env(&a, "c", "CONSOLE", "ttya")?;
    let variant = "iso";
    let install = !a.opts().opt_present("N");
    let group = arg_or_env(&a, "g", "GROUP", "helios")?;
    let name = arg_or_env(&a, "O", "OUTPUT_NAME", "helios-dev")?;

    let proto = setup_genproto(&a)?;

    let log = &l.context().log;

    let cfg = config::Config::load(log)?;

    let outputs = vec![
        repo::rel_path(
            Some(&cfg.mountpoint),
            &["output", &format!("{group}-eltorito-efi.pcfs")],
        )?,
        repo::rel_path(
            Some(&cfg.mountpoint),
            &["output", &format!("{group}-{machine}-{console}-{variant}.iso")],
        )?,
    ];

    for o in &outputs {
        maybe_unlink_as_root(o)?;
    }

    let step_pre = |efi: bool| -> Result<(String, Command)> {
        let tname = if efi {
            "eltorito-efi".to_string()
        } else {
            format!("{machine}-{console}-{variant}")
        };
        info!(log, "image builder template: {tname}...");
        Ok((tname, basecmd(&cfg, &group, &name)?))
    };

    let mut step_post = |tname: String, mut cmd: Command| -> Result<()> {
        for f in &extra_features {
            cmd.arg("-F").arg(f);
        }
        ensure::run2(log, &mut cmd)?;
        info!(log, "{tname} complete after {} seconds", sw.lap().as_secs());
        Ok(())
    };

    let (tname, mut cmd) = step_pre(true)?;
    cmd.arg("-n").arg(&tname);
    if install {
        cmd.arg("-F").arg("install");
    }
    step_post(tname, cmd)?;

    let (tname, mut cmd) = step_pre(false)?;
    cmd.arg("-n").arg(&tname);
    if install {
        cmd.arg("-F").arg("install");
    }
    if let Some(proto) = &proto {
        cmd.arg("-F").arg("genproto");
        cmd.arg("-E").arg(proto);
    }
    step_post(tname, cmd)?;

    for o in &outputs {
        if !o.is_file() {
            bail!("expected output file {o:?} was not generated?");
        }
    }

    info!(
        log,
        "after {} seconds, output files: {outputs:?}",
        sw.total().as_secs()
    );

    Ok(())
}
