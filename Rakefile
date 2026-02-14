desc "Build the site"
task :build do
  sh "bundle exec middleman build"
end

desc "Build and deploy to GitHub Pages (master branch)"
task :deploy => :build do
  rm_rf "build/.git"
  cd "build" do
    sh "git init -b master"
    sh "git add -A"
    sh "git commit -m 'Deploy at #{Time.now}'"
    sh "git push -f git@github.com:aranair/aranair.github.io.git master"
  end
end

desc "Start development server"
task :server do
  sh "bundle exec middleman server"
end
