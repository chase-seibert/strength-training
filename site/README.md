# Lift Chase site draft

The static homepage and privacy policy are served directly from this directory. The simulator screenshot PNGs in `assets/screenshots/` are the unmodified masters used on the pages and intended for the App Store listing.

Preview locally from the repository root:

```sh
make site-serve
```

The site is not published by this preview command. The repository's GitHub Pages workflow publishes the contents of `site/` after Pages is enabled with GitHub Actions as its source.
