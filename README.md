# void-nat

## Layout

```sh
    ~/void-build/
    ├── void-packages/     # upstream clone
    └── void-nat/          # this repo
```

## Fresh machine

```sh
    git clone https://github.com/natrium404/void-nat.git
    void-nat/scripts/bootstrap.sh
```

Or, if `void-packages` already exists:

```sh
    git clone https://github.com/natrium404/void-nat.git ~/void-build/void-nat
    ~/void-build/void-nat/scripts/build.sh
```

## Scripts
```sh
    scripts/sync.sh            # pull upstream safely
    scripts/check.sh [pkg...]  # check and report status of each pkg
    scripts/build.sh [pkg...]  # sync and build pkg
    scripts/clean.sh           # clean all the mess and ready for sync
    scripts/purge.sh           # remove all the cache, build pkgs
```

## Adding a package
Read void-packages [MANUAL](https://github.com/natrium404/void-packages-11/blob/master/Manual.md)
Also the [CONTRIBUTING](https://github.com/natrium404/void-packages-11/blob/master/CONTRIBUTING.md)

```sh
    mkdir -p srcpkgs/<pkgname>
    $EDITOR srcpkgs/<pkgname>/template
    git add srcpkgs/<pkgname> && git commit -m "New package: <pkgname>-<version>"
    git push
```
