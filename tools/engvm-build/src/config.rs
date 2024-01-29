use crate::prelude::*;
/*
 * Copyright 2024 Oxide Computer Company
 */

use std::process::Command;

fn old_config_dataset() -> Result<String> {
    /*
     * Everything was a shell script before.  Use the shell to attempt to lift
     * that configuration out.
     */
    let etc = repo::top_path(&["image", "etc"])?;
    let defs = repo::rel_path(Some(&etc), &["defaults.sh"])?;
    let defs = defs.to_str().unwrap();
    let cfg = repo::rel_path(Some(&etc), &["config.sh"])?;
    let cfg = cfg.to_str().unwrap();

    let script = format!(
        "if ! . '{defs}'; then exit 1; fi; \
        if [[ -f '{cfg}' ]]; then \
        if ! . '{cfg}'; then exit 1; fi; \
        fi; printf '%s\\n' \"$DATASET\""
    );

    let out = Command::new("/usr/bin/bash").arg("-c").arg(script).output()?;
    Ok(out.simple_stdout_one_line()?.trim().to_string())
}

pub(crate) struct Config {
    pub dataset: String,
    pub mountpoint: String,
}

impl Config {
    pub(crate) fn load(log: &Logger) -> Result<Config> {
        let dataset = old_config_dataset()?;
        info!(log, "dataset = {dataset}");

        if !zfs::dataset_exists(&dataset)? {
            /*
             * XXX Create it?
             */
            bail!("dataset {dataset} does not exist yet; create with zfs(8)");
        }

        let mountpoint = zfs::zfs_get(&dataset, "mountpoint")?;
        info!(log, "mountpoint = {mountpoint}");

        Ok(Config { dataset, mountpoint })
    }
}
