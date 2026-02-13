# aranair.github.io

Personal tech blog built with [Middleman](https://middlemanapp.com/).

## Stack

- **Middleman** 4.6 (static site generator)
- **Ruby** 3.3
- **Bootstrap** 3.4 (via `bootstrap-sass` gem)
- **Font Awesome** 4.7 (via `font-awesome-sass` gem)
- **Sprockets** 4.x (asset pipeline)
- **SassC** (SCSS compilation)

## Setup

```bash
bundle install
```

## Development

```bash
bundle exec middleman server
```

## Build

```bash
bundle exec middleman build
```

Build output goes to `build/`.

## Deploy

```bash
rake deploy
```

Builds and pushes the `build/` directory to the `master` branch for GitHub Pages.

## Known Workarounds

There is a monkey-patch in `config.rb` for a bug in `middleman-sprockets` 4.1.1 with Sprockets 4.x. The gem passes the full source extension (e.g. `stylesheets/blog.css.scss`) when looking up assets, but Sprockets 4 needs the logical path without the template extension (`stylesheets/blog.css`) to trigger SCSS→CSS compilation. The patch strips `.scss`/`.sass`/`.coffee`/`.es6` extensions in `Resource#sprockets_asset` before the lookup.
