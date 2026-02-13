###
# Blog settings
###

require 'reading_time'

activate :reading_time
activate :meta_tags

Time.zone = "Singapore"

set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, smartypants: true

activate :blog do |blog|
  blog.prefix = "posts"
  blog.taglink = "tags/{tag}.html"
  blog.layout = "posts_layout"
  blog.summary_separator = /(READMORE)/
  blog.summary_length = 350
  blog.default_extension = ".markdown"

  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"

  # Enable pagination
  blog.paginate = true
  blog.per_page = 10
  blog.page_link = "page/{num}"
end

page "/feed.xml", layout: false
page "/sitemap.xml", layout: false

###
# Page options, layouts, aliases and proxies
###

# Proxy pages (https://middlemanapp.com/advanced/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", locals: {
#  which_fake_page: "Rendering a fake page with a local variable" }

###
# Helpers
###

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'

activate :directory_indexes

# Exclude non-HTML assets from directory_indexes
page "/stylesheets/*", directory_index: false
page "/javascripts/*", directory_index: false
page "/images/*", directory_index: false

activate :sprockets do |c|
  c.imported_asset_path = 'assets'
end

# Add gem SCSS paths for Middleman's Sass renderer (non-sprockets .scss files)
sass_gem_paths = [
  File.join(Gem.loaded_specs['bootstrap-sass'].full_gem_path, 'assets', 'stylesheets'),
  File.join(Gem.loaded_specs['font-awesome-sass'].full_gem_path, 'assets', 'stylesheets'),
]
set :sass_assets_paths, sass_gem_paths + [File.join(__dir__, 'source', 'stylesheets')]

# Set global SassC load paths so both Middleman's renderer and Sprockets can find them
require 'sassc'
::SassC.load_paths.concat(sass_gem_paths)
::SassC.load_paths << File.join(__dir__, 'source', 'stylesheets')

# Fix middleman-sprockets 4.1.1 bug with Sprockets 4.x:
# When sprockets_path includes the template extension (e.g. 'stylesheets/blog.css.scss'),
# Sprockets 4 returns the raw SCSS source instead of compiling it. Sprockets 4 needs the
# logical path without the template extension (e.g. 'stylesheets/blog.css') to trigger
# the SCSS->CSS transformation pipeline.
require 'middleman-sprockets/resource'
module SprocketsResourceFix
  def sprockets_asset
    # Strip template extensions so Sprockets resolves the logical path correctly
    logical_path = @sprockets_path.sub(/\.(scss|sass|coffee|es6)$/, '')
    ::Middleman::Util.instrument 'sprockets.asset_lookup', asset: self do
      @environment[logical_path] || raise(::Sprockets::FileNotFound, logical_path)
    end
  rescue StandardError => e
    raise e if @app.build?

    @errored = true
    self.class::Error.new(e, ext)
  end
end
Middleman::Sprockets::Resource.prepend(SprocketsResourceFix)

configure :development do
  activate :livereload
  activate :syntax

  activate :disqus do |d|
    d.shortname = 'homan-gh-blog-test'
  end
end

# Build-specific configuration
configure :build do
  activate :disqus do |d|
    d.shortname = "homan-gh-blog"
  end

  activate :syntax

  # Enable cache buster
  activate :asset_hash
  activate :minify_css
  activate :minify_javascript
end

# Deploy via: rake deploy
# (middleman-deploy gem has been removed as it's abandoned)
