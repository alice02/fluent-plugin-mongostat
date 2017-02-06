# Fluent::Plugin::Mongostat, a plugin for Fluentd

## Overview
- mongostat log input plugin for fluentd


## Dependencies
- mongostat >= 3.0.0


## Installation
```
$ rake build
$ fluent-gem install --local pkg/fluent-plugin-mongostat.gem
```

## Usage
In your Fluentd configuration, use `@type mongostat`.
```
<source>
  @type mongostat
  tag mongostat.__HOSTNAME__
  refresh_interval 10
</source>
```

## Configuration
### tag
the tag of event.

### option
Option for mongostat command.
- default: None.

### refresh_interval
Interval of get mongostat metrics.
- default: 10