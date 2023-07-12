/*
 * Copyright 2020 Oxide Computer Company
 */

#![allow(unused)]

use anyhow::{bail, Result};
use atty::Stream;
use serde::Deserialize;
use slog::{Drain, Logger};
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;
use std::time::{Instant, Duration};

pub use slog::{debug, error, info, o, trace, warn};

/**
 * Initialise a logger which writes to stdout, and which does the right thing on
 * both an interactive terminal and when stdout is not a tty.
 */
pub fn init_log() -> Logger {
    let dec = slog_term::TermDecorator::new().stdout().build();
    if atty::is(Stream::Stdout) {
        let dr = Mutex::new(slog_term::CompactFormat::new(dec).build()).fuse();
        slog::Logger::root(dr, o!())
    } else {
        let dr = Mutex::new(
            slog_term::FullFormat::new(dec).use_original_order().build(),
        )
        .fuse();
        slog::Logger::root(dr, o!())
    }
}

pub fn sleep(s: u64) {
    std::thread::sleep(std::time::Duration::from_secs(s));
}

pub trait OutputExt {
    fn info(&self) -> String;
    fn simple_stdout(&self) -> Result<String>;
    fn simple_stdout_one_line(&self) -> Result<String>;
}

impl OutputExt for std::process::Output {
    fn info(&self) -> String {
        let mut out = String::new();

        if let Some(code) = self.status.code() {
            out.push_str(&format!("exit code {}", code));
        }

        /*
         * Attempt to render stderr from the command:
         */
        let stderr = String::from_utf8_lossy(&self.stderr).trim().to_string();
        let extra = if stderr.is_empty() {
            /*
             * If there is no stderr output, this command might emit its
             * failure message on stdout:
             */
            String::from_utf8_lossy(&self.stdout).trim().to_string()
        } else {
            stderr
        };

        if !extra.is_empty() {
            if !out.is_empty() {
                out.push_str(": ");
            }
            out.push_str(&extra);
        }

        out
    }

    fn simple_stdout(&self) -> Result<String> {
        if !self.status.success() {
            bail!("command failed: {}", self.info());
        }

        Ok(String::from_utf8(self.stdout.clone())?)
    }

    fn simple_stdout_one_line(&self) -> Result<String> {
        let out = self.simple_stdout()?;
        if out.lines().count() != 1 {
            bail!("command failed: expected one line, got {:?}", out);
        }
        Ok(out.lines().next().unwrap().to_string())
    }
}

pub fn read_toml<P, O>(path: P) -> Result<O>
where
    P: AsRef<Path>,
    for<'de> O: Deserialize<'de>,
{
    let f = File::open(path.as_ref())?;
    let mut buf: Vec<u8> = Vec::new();
    let mut r = BufReader::new(f);
    r.read_to_end(&mut buf)?;
    Ok(toml::from_slice(&buf)?)
}

fn exists<P: AsRef<Path>>(path: P) -> Result<Option<std::fs::Metadata>> {
    let p = path.as_ref();
    match std::fs::metadata(p) {
        Ok(m) => Ok(Some(m)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => bail!("checking for path {}: {}", p.display(), e),
    }
}

pub fn exists_file<P: AsRef<Path>>(path: P) -> Result<bool> {
    let p = path.as_ref();

    if let Some(m) = exists(p)? {
        if m.is_file() {
            Ok(true)
        } else {
            bail!("path {} exists but is not a file", p.display());
        }
    } else {
        Ok(false)
    }
}

pub fn exists_dir<P: AsRef<Path>>(path: P) -> Result<bool> {
    let p = path.as_ref();

    if let Some(m) = exists(p)? {
        if m.is_dir() {
            Ok(true)
        } else {
            bail!("path {} exists but is not a directory", p.display());
        }
    } else {
        Ok(false)
    }
}

/**
 * Try to unlink a file.  If it did not exist, treat that as a success; report
 * any other error.
 */
pub fn maybe_unlink(f: &Path) -> Result<()> {
    match std::fs::remove_file(f) {
        Ok(_) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => bail!("could not remove {f:?}: {e:?}"),
    }
}

/**
 * The image builder runs some commands as root, producing output files that are
 * then owned as root.  Use pfexec(1) to remove them if they exist:
 */
pub fn maybe_unlink_as_root(f: &Path) -> Result<()> {
    let out = Command::new("/usr/bin/pfexec")
        .env_clear()
        .arg("/usr/bin/rm")
        .arg("-f")
        .arg(f)
        .output()?;

    if !out.status.success() {
        bail!("pfexec rm -f {f:?} failed: {}", out.info());
    }

    Ok(())
}

pub struct StopWatch {
    start: Instant,
    lap: Instant,
}

impl StopWatch {
    pub fn start() -> StopWatch {
        let now = Instant::now();
        StopWatch { start: now, lap: now }
    }

    pub fn lap(&mut self) -> Duration {
        let delta = Instant::now().saturating_duration_since(self.lap);
        self.lap = Instant::now();
        delta
    }

    pub fn total(&self) -> Duration {
        Instant::now().saturating_duration_since(self.start)
    }
}