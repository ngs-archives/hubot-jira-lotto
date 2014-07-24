hubot-jira-lotto
===========

[![Build Status][travis-badge]][travis]
[![npm-version][npm-badge]][npm]

A [Hubot] script to pick assignee for [JIRA] issues.

```
me    > hubot pick an assignee for BUGS-32 from bugfixers
hubot > @ngs please fix BUG-32
        https://myjira.atlassian.net/browse/BUGS-32
```

Command
--------

```
hubot pick (an) assignee (for) <ISSUE-NUMBER> from <ASSIGNEE-GROUP>
```

Installation
------------

1. Add `hubot-jira-lotto` to dependencies.

  ```bash
  npm install --save hubot-jira-lotto
  ```

2. Update `external-scripts.json`

  ```json
  ["hubot-jira-lotto"]
  ```

Configuration
-------------

```
HUBOT_JIRA_LOGIN
HUBOT_JIRA_PASSWORD
HUBOT_JIRA_DOMAIN
```

This Hubot script require **Admin priviledges** for the login account.

Please add the login account to *administrators* group.

Converting JIRA username to chat username to mention
----------------------------------------------------

If you use different username in your adapter (Campfire, HipChat, Slack ...) and JIRA, you can define converter method in `robot` instance.

```coffeescript
# scripts/convert-handle.coffee
module.exports = (robot)->
  map =
    ngs: 'atsushi_nagase'
  robot.convertHandle = (name)->
    map[name] || name
```

Author
------

[Atsushi Nagase]

License
-------

[MIT License]


[Hubot]: https://hubot.github.com/
[Atsushi Nagase]: http://ngs.io/
[MIT License]: LICENSE
[travis-badge]: https://travis-ci.org/ngs/hubot-jira-lotto.svg?branch=master
[npm-badge]: http://img.shields.io/npm/v/hubot-jira-lotto.svg
[travis]: https://travis-ci.org/ngs/hubot-jira-lotto
[npm]: https://www.npmjs.org/package/hubot-jira-lotto
[JIRA]: https://www.atlassian.com/software/jira
