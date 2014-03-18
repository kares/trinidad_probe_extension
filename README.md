# Trinidad Probe Extension

Advanced manager and monitor using [PSI Probe][0], packaged for Trinidad.


## Install

Along with Trinidad in your application's *Gemfile* :

```ruby
group :trinidad do
  platform :jruby do
    gem 'trinidad', require: false
    gem 'trinidad_probe_extension', require: false
  end
end
```

or install it yourself as a plain old gem :

    $ gem install trinidad_probe_extension


## Configure

Like all extensions set it up in the configuration file (e.g. *trinidad.yml*).

```yaml
---
  # ...
  extensions:
    probe: /__probe__
```


## Copyright

Copyright (c) 2014 [Karol Bucek](http://kares.org).
See LICENSE (http://www.gnu.org/licenses/gpl-2.0.html) for details.

[0]: https://code.google.com/p/psi-probe/