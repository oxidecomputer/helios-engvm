use crate::prelude::*;
/*
 * Copyright 2024 Oxide Computer Company
 */

use std::{
    io::Write,
    os::unix::prelude::PermissionsExt,
    path::{Path, PathBuf},
};

use helios_build_utils::tree;
use walkdir::WalkDir;

/*
 * If we have been provided an extra proto directory, we want to include all of
 * the files and directories and symbolic links that have been assembled in that
 * proto area in the final image.  The image-builder tool cannot do this
 * natively because there is no way to know what metadata to use for the files
 * without some kind of explicit manifest provided as input to ensure_*
 * directives.
 *
 * For our purposes here, it seems sufficient to use the mode bits as-is and
 * just request that root own the files in the resultant image.  We generate a
 * partial template by walking the proto area, for inclusion when the "genproto"
 * feature is also enabled in our main template.
 */
pub fn genproto(proto: &Path, output_template: &Path) -> Result<()> {
    let rootdir = PathBuf::from("/");
    let mut steps: Vec<serde_json::Value> = Default::default();

    for ent in WalkDir::new(proto).min_depth(1).into_iter() {
        let ent = ent?;

        let relpath = tree::unprefix(proto, ent.path())?;
        if relpath == PathBuf::from("bin") {
            /*
             * On illumos, /bin is always a symbolic link to /usr/bin.
             */
            bail!(
                "proto {:?} contains a /bin directory; should use /usr/bin",
                proto
            );
        }

        /*
         * Use the relative path within the proto area as the absolute path
         * in the image; e.g., "proto/bin/id" would become "/bin/id" in the
         * image.
         */
        let path = tree::reprefix(proto, ent.path(), &rootdir)?;
        let path = path.to_str().unwrap();

        let md = ent.metadata()?;
        let mode = format!("{:o}", md.permissions().mode() & 0o777);
        if md.file_type().is_symlink() {
            let target = std::fs::read_link(ent.path())?;

            steps.push(serde_json::json!({
                "t": "ensure_symlink", "link": path, "target": target,
                "owner": "root", "group": "root",
            }));
        } else if md.file_type().is_dir() {
            /*
             * Some system directories are owned by groups other than "root".
             * The rules are not exact; this is an approximation to reduce
             * churn:
             */
            let group = if relpath.starts_with("var")
                || relpath.starts_with("etc")
                || relpath.starts_with("lib/svc/manifest")
                || relpath.starts_with("platform")
                || relpath.starts_with("kernel")
                || relpath == PathBuf::from("usr")
                || relpath == PathBuf::from("usr/share")
                || relpath.starts_with("usr/platform")
                || relpath.starts_with("usr/kernel")
                || relpath == PathBuf::from("opt")
            {
                "sys"
            } else if relpath.starts_with("lib") || relpath.starts_with("usr") {
                "bin"
            } else {
                "root"
            };

            steps.push(serde_json::json!({
                "t": "ensure_dir", "dir": path,
                "owner": "root", "group": group, "mode": mode,
            }));
        } else if md.file_type().is_file() {
            steps.push(serde_json::json!({
                "t": "ensure_file", "file": path, "extsrc": relpath,
                "owner": "root", "group": "root", "mode": mode,
            }));
        } else {
            bail!("unhandled file type at {:?}", ent.path());
        }
    }

    let out = serde_json::to_vec_pretty(&serde_json::json!({
        "steps": steps,
    }))?;
    let mut f = std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(output_template)?;
    f.write_all(&out)?;
    f.flush()?;

    Ok(())
}
