#[allow(dead_code)]
mod ensure;
mod common;
#[allow(dead_code)]
mod repo;
#[allow(dead_code)]
mod zfs;
mod projects;
#[allow(dead_code)]
mod config;
mod genproto;

mod cmds;
use cmds::setup::setup;
use cmds::image::image;

mod prelude {
    pub(crate) use crate::common::*;
    pub(crate) use crate::Stuff;
    pub(crate) use crate::{ensure, repo, zfs, projects, config, genproto};
    pub(crate) use anyhow::{bail, Result};
    pub(crate) use hiercmd::prelude::*;
    pub(crate) use slog::{info, Logger};
}
use prelude::*;

struct Stuff {
    log: Logger,
}

impl Default for Stuff {
    fn default() -> Self {
        Self { log: init_log() }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let mut l = Level::new("engvm-build", Stuff::default());

    l.cmd(
        "setup",
        "clone required repositories and run setup tasks",
        cmd!(setup),
    )?;
    l.cmd(
        "image",
        "image building",
        cmd!(image),
    )?;

    sel!(l).run().await
}
