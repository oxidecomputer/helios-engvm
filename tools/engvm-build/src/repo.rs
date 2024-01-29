use crate::prelude::*;
/*
 * Copyright 2024 Oxide Computer Company
 */

use std::{
    ffi::OsStr,
    path::{Component, Path, PathBuf},
};

const NO_PATH: Option<PathBuf> = None;

fn pc(s: &str) -> Component {
    Component::Normal(OsStr::new(s))
}

/**
 * Determine the location of the top-level helios-engvm.git clone.
 */
pub fn top() -> Result<PathBuf> {
    /*
     * Start with the path of the current executable, and discard the last
     * component of that path (the executable file itself) so that we can reason
     * about the directory structure in which it is found.
     */
    let mut exe = std::env::current_exe()?;
    let last: Vec<Component> = exe.components().rev().skip(1).collect();

    if last.len() < 4 {
        bail!("could not determine path from {:?}", last);
    }

    if (last[0] != pc("debug") && last[0] != pc("release"))
        || last[1] != pc("target")
        || last[2] != pc("engvm-build")
        || last[3] != pc("tools")
    {
        bail!("could not determine path from {:?}", last);
    }

    for _ in 0..5 {
        assert!(exe.pop());
    }

    Ok(exe)
}

pub fn rel_path<P: AsRef<Path>>(
    p: Option<P>,
    components: &[&str],
) -> Result<PathBuf> {
    let mut top =
        if let Some(p) = p { p.as_ref().to_path_buf() } else { top()? };
    for c in components {
        top.push(c);
    }
    Ok(top)
}

pub fn top_path(components: &[&str]) -> Result<PathBuf> {
    let mut top = top()?;
    for c in components {
        top.push(c);
    }
    Ok(top)
}

pub fn abs_path<P: AsRef<Path>>(p: P) -> Result<PathBuf> {
    let p = p.as_ref();
    Ok(if p.is_absolute() {
        p.to_path_buf()
    } else {
        let mut pp = std::env::current_dir()?;
        pp.push(p);
        pp.canonicalize()?
    })
}

fn ensure_dir(components: &[&str]) -> Result<PathBuf> {
    let dir = top_path(components)?;
    if !exists_dir(&dir)? {
        std::fs::create_dir(&dir)?;
    }
    Ok(dir)
}
