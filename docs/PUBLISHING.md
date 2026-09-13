# First publication

The working tree is prepared for an independent fork. No release has been
published and no commit is created by the preparation itself.

1. Use **Hyprworld** as the public project name.
2. Create `tdemers218/hyprworld` on GitHub. Installation instructions already
   target `https://github.com/tdemers218/hyprworld.git`.
3. Preserve upstream history and credit. In the development checkout, `origin`
   may still point at `kirollosatef/hyprscroll2d`; inspect `git remote -v` and set
   your own push destination before pushing. Do not push this fork to upstream.
4. Run `make check` and `omarchy plugin validate .` in an Omarchy environment.
5. Review `git diff` and `git status --short`, including new files. Local `.bak.*`
   files and Python caches are ignored, not deleted.
6. Test an installation of the renamed plugin in a prepared Omarchy session,
   including migration, settings, overview, monitor switching, and removal.
7. Add an actual screenshot or recording of the fork if desired. The inherited
   `preview.png` is historical and is not used as a current README demo.
8. Commit and push to your own repository. When ready to release, replace the
   unreleased changelog heading with the release date and tag `v0.1.0`.

The package ID is `io.github.tdemers218.hyprworld`. Keep `manifest.json` and `Workspaces.qml` consistent if changing it.
A marketplace listing is a separate submission; this repository does not claim
marketplace approval or bundled Omarchy status.
