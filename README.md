# Fluent::Plugin::Mongostat, a plugin for Fluentd

[![CircleCI](https://circleci.com/gh/alice02/fluent-plugin-mongostat.svg?style=svg)](https://circleci.com/gh/alice02/fluent-plugin-mongostat)

## Overview
- mongostat log input plugin for fluentd


## Dependencies
- mongostat >= 3.0.0


## Installation
```
$ fluent-gem install fluent-plugin-mongostat
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
- default: 30
