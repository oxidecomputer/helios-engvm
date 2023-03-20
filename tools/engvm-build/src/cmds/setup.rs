use crate::prelude::*;

pub(crate) async fn setup(mut l: Level<Stuff>) -> Result<()> {
    no_args!(l);

    let log = &l.context().log;

    let top = repo::top_path(&["image"])?;
    let projcfg = repo::rel_path(Some(&top), &["etc", "projects.toml"])?;
    let tfiles = repo::rel_path(Some(&top), &["templates", "files"])?;

    projects::project_setup(log, &projcfg, &top, &tfiles)?;

    Ok(())
}
