use crate::prelude::*;

use std::{collections::HashMap, path::Path, process::Command, time::Instant};

use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Projects {
    #[serde(default)]
    project: HashMap<String, Project>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum StringOrBool {
    String(String),
    Bool(bool),
}

#[derive(Debug, Deserialize)]
struct Project {
    github: Option<String>,
    url: Option<String>,

    /*
     * Attempt to update this repository from upstream when running setup?
     */
    #[serde(default)]
    auto_update: bool,

    /*
     * When cloning or updating this repository, pin to this commit hash:
     */
    #[serde(default)]
    commit: Option<String>,

    /*
     * If this is a private repository, we force the use of SSH:
     */
    #[serde(default)]
    use_ssh: bool,

    /*
     * Run "cargo build" in this project to produce tools that we need:
     */
    #[serde(default)]
    cargo_build: bool,
    #[serde(default)]
    use_debug: bool,

    /*
     * If this environment variable is set to "no", we will skip cloning and
     * building this project.
     */
    unless_env: Option<String>,

    /*
     * Copy these extra files into the image builder template area, so that they
     * can be referenced in templates.
     */
    #[serde(default)]
    template_files: HashMap<String, StringOrBool>,
}

impl Project {
    fn url(&self, use_ssh: bool) -> Result<String> {
        if let Some(url) = self.url.as_deref() {
            Ok(url.to_string())
        } else if let Some(github) = self.github.as_deref() {
            Ok(if use_ssh || self.use_ssh {
                format!("git@github.com:{}.git", github)
            } else {
                format!("https://github.com/{}.git", github)
            })
        } else {
            bail!("need github or url?");
        }
    }

    fn skip(&self) -> bool {
        self.skip_reason().is_some()
    }

    fn skip_reason(&self) -> Option<String> {
        if let Some(key) = self.unless_env.as_deref() {
            if let Ok(value) = std::env::var(key) {
                let value = value.to_ascii_lowercase();
                if value == "no" || value == "0" || value == "false" {
                    return Some(format!("{key:?} is set to {value:?}"));
                }
            }
        }

        None
    }
}

pub(crate) fn project_setup(
    log: &Logger,
    cfgpath: &Path,
    projpath: &Path,
    tfilepath: &Path,
) -> Result<()> {
    let p: Projects = read_toml(cfgpath)?;

    info!(log, "cloning and updating projects...");
    for (name, project) in p.project.iter() {
        let path = repo::rel_path(Some(projpath), &[&name])?;
        let url = project.url(false)?;

        if let Some(reason) = project.skip_reason() {
            info!(log, "skipping project {name:?} because {reason}");
            continue;
        }

        let log = log.new(o!("project" => name.to_string()));
        info!(log, "project {name}: {project:?}");

        if exists_dir(&path)? {
            info!(log, "clone {url} exists already at {path:?}");
            if project.auto_update {
                info!(log, "fetching updates for clone ...");
                let mut child = if let Some(commit) = &project.commit {
                    Command::new("git")
                        .current_dir(&path)
                        .arg("fetch")
                        .arg("origin")
                        .arg(commit)
                        .spawn()?
                } else {
                    Command::new("git")
                        .current_dir(&path)
                        .arg("fetch")
                        .spawn()?
                };

                let exit = child.wait()?;
                if !exit.success() {
                    bail!("fetch in {} failed", path.display());
                }

                if let Some(commit) = &project.commit {
                    info!(log, "pinning to commit {commit}...");
                    let mut child = Command::new("git")
                        .current_dir(&path)
                        .arg("checkout")
                        .arg(commit)
                        .spawn()?;

                    let exit = child.wait()?;
                    if !exit.success() {
                        bail!("update merge in {} failed", path.display());
                    }
                } else {
                    info!(log, "rolling branch forward...");
                    let mut child = Command::new("git")
                        .current_dir(&path)
                        .arg("merge")
                        .arg("--ff-only")
                        .spawn()?;

                    let exit = child.wait()?;
                    if !exit.success() {
                        bail!("update merge in {} failed", path.display());
                    }
                }

                info!(log, "updating submodules...");
                let mut child = Command::new("git")
                    .current_dir(&path)
                    .arg("submodule")
                    .arg("update")
                    .arg("--recursive")
                    .spawn()?;

                let exit = child.wait()?;
                if !exit.success() {
                    bail!("submodule update in {} failed", path.display());
                }
            }
        } else {
            info!(log, "cloning {url} at {path:?}...");
            let mut child = Command::new("git")
                .arg("clone")
                .arg("--recurse-submodules")
                .arg(&url)
                .arg(&path)
                .spawn()?;

            let exit = child.wait()?;
            if !exit.success() {
                bail!("clone of {} to {} failed", url, path.display());
            }

            if let Some(commit) = &project.commit {
                info!(log, "fetching commit {commit} for clone ...");
                let mut child = Command::new("git")
                    .current_dir(&path)
                    .arg("fetch")
                    .arg("origin")
                    .arg(commit)
                    .spawn()?;

                let exit = child.wait()?;
                if !exit.success() {
                    bail!("fetch in {} failed", path.display());
                }

                info!(log, "pinning to commit {commit}...");
                let mut child = Command::new("git")
                    .current_dir(&path)
                    .arg("checkout")
                    .arg(commit)
                    .spawn()?;

                let exit = child.wait()?;
                if !exit.success() {
                    bail!("update merge in {} failed", path.display());
                }

                info!(log, "updating submodules...");
                let mut child = Command::new("git")
                    .current_dir(&path)
                    .arg("submodule")
                    .arg("update")
                    .arg("--recursive")
                    .spawn()?;

                let exit = child.wait()?;
                if !exit.success() {
                    bail!("submodule update in {} failed", path.display());
                }
            }

            info!(log, "clone ok!");
        }
    }

    /*
     * Perform setup in project repositories that require it.
     */
    info!(log, "performing per-project setup and builds...");
    for (name, project) in p.project.iter().filter(|p| p.1.cargo_build) {
        if project.skip() {
            continue;
        }

        let path = repo::rel_path(Some(projpath), &[&name])?;
        info!(log, "building project {:?} at {}", name, path.display());
        let start = Instant::now();
        let mut args = vec!["cargo", "build", "--locked"];
        if !project.use_debug {
            args.push("--release");
        }
        ensure::run_in(log, &path, &args)?;
        let delta = Instant::now().saturating_duration_since(start).as_secs();
        info!(log, "building project {:?} ok ({} seconds)", name, delta);

        for (name, src) in project.template_files.iter() {
            let src = match src {
                StringOrBool::String(s) => s,
                StringOrBool::Bool(true) => name,
                StringOrBool::Bool(false) => continue,
            };

            let src = repo::rel_path(Some(&path), &[src.as_str()])?;
            let dst = repo::rel_path(Some(tfilepath), &[name.as_str()])?;

            info!(log, "copying {src:?} to {dst:?}");

            maybe_unlink(&dst)?;
            std::fs::copy(&src, &dst)?;
        }
    }

    Ok(())
}
