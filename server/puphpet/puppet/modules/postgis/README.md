PostGis Puppet module
=====================

[![Puppet Forge](http://img.shields.io/puppetforge/v/camptocamp/postgis.svg)](https://forge.puppetlabs.com/camptocamp/postgis)
[![Build Status](https://travis-ci.org/camptocamp/puppet-postgis.png?branch=master)](https://travis-ci.org/camptocamp/puppet-postgis)

Usage
-----

```puppet
include ::postgis
```

This will install the postgis package, create a `template\_postgis` template
database with geometry_columns and geometry_columns tables.

This module is provided by [Camptocamp](http://www.camptocamp.com/)

## Contributing

Please report bugs and feature request using [GitHub issue
tracker](https://github.com/camptocamp/puppet-postgis/issues).

For pull requests, it is very much appreciated to check your Puppet manifest
with [puppet-lint](http://puppet-lint.com/) to follow
the recommended Puppet style guidelines from the
[Puppet Labs style guide](http://docs.puppetlabs.com/guides/style_guide.html).

