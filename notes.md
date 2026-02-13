# Build Notes

## Ruby & Bundler
- Ruby 3.3.10 (via rbenv)
- Bundler 2.7.2 (required by middleman-core ~> bundler 2.x)
- Run with: `bundle _2.7.2_ exec middleman build`

## Deploy
- `middleman-deploy` gem was removed (abandoned/incompatible)
- Use `rake deploy` instead (see Rakefile)
