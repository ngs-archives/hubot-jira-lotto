# Description:
#   A Hubot script to pick assignee for JIRA issues.
#
# Configuration:
#   HUBOT_JIRA_LOGIN (required)
#   HUBOT_JIRA_PASSWORD (required)
#   HUBOT_JIRA_DOMAIN (required)
#
# Commands:
#   hubot pick (an) assignee (for) <ISSUE-NUMBER> from <ASSIGNEE-GROUP> - Pick an assignee for JIRA issues.
#

{ JiraApi } = require 'jira'
weighted    = require 'weighted'
path        = require 'path'
fs          = require 'fs'

module.exports = (robot) ->
  { HUBOT_JIRA_DOMAIN, HUBOT_JIRA_LOGIN, HUBOT_JIRA_PASSWORD } = process.env
  missings = []
  'HUBOT_JIRA_DOMAIN HUBOT_JIRA_LOGIN HUBOT_JIRA_PASSWORD'.split(/\s+/g).forEach (key)->
    missings.push key unless process.env[key]?
  if missings.length > 0
    robot.logger.error "Required configuration#{ if missings.length == 1 then 'is' else 's are' } missing: #{ missings.join ', ' }"

  jiraApi = ->
    @jiraApi ||= new JiraApi 'https', HUBOT_JIRA_DOMAIN, null, HUBOT_JIRA_LOGIN, HUBOT_JIRA_PASSWORD, '2', true

  getUsers = (group, callback)->
    doRequest 'GET', "/group?groupname=#{group}&expand=users", null, (error, res)->
      callback error, res?.users?.items

  getIssues = (project, callback)->
    startAt = 0
    maxResults = 1000
    jql = "project = '#{project}'"
    buffer = []
    do loadNext = ->
      fields = ['assignee']
      options = { maxResults, startAt, fields }
      jiraApi().searchJira jql, options, (error, { total, issues })->
        robot.logger.info "Total: #{total} StartAt: #{startAt} MaxResults: #{maxResults}"
        buffer = buffer.concat issues if issues?
        if error
          callback error, buffer
        else if maxResults + startAt < total
          startAt += maxResults
          do loadNext
        else
          callback null, buffer

  assignUser = (issueNumber, name, callback)->
    doRequest 'PUT', "/issue/#{issueNumber}/assignee", name, callback

  doRequest = (method, path, body, callback) ->
    j = jiraApi()
    options = {
      rejectUnauthorized: j.strictSSL
      uri: j.makeUri(path)
      json: true
      method
    }
    options.body = body if body?
    j.doRequest options, (error, res, body)->
      try
        if body and typeof body is 'string'
          body = JSON.parse body
        else if !body
          body = null
        if body?.errorMessages instanceof Array
          error = new Error body.errorMessages.join "\n"
          body = null
        callback error, body
      catch e
        callback e, null

  doLotto = (issueNumber, group, callback)->
    robot.logger.info "Picking assignee for #{issueNumber} from #{group}"
    project = issueNumber.match(/^([^\-]+)/)[1]
    getIssues project, (error, issues)->
      return callback error, null if error
      getUsers group, (error, users)->
        return callback error, null if error
        user = pickUser { users, issues, issueNumber }
        assignUser issueNumber, user, (error, status)->
          if error
            callback error, null
          else
            callback null, user

  pickUser = (options)->
    obj = getWeightedOptions options
    name = weighted.select obj, null, bugfixLotto.random
    { users } = options
    for user in users
      return user if user.name is name
    null

  getWeightedOptions = ({ users, issues, issueNumber })->
    obj = {}
    total = issues.length
    users.forEach (user)->
      obj[user.name] = total
    total = total * users.length
    found = no
    issues.forEach ({ fields, key })->
      if issueNumber is key
        found = yes
      else if obj[fields?.assignee?.name]?
        obj[fields.assignee.name]--
        total--
    throw new Error "Issue #{issueNumber} not found." unless found
    for k, v of obj
      obj[k] = v/total
    obj

  random = ->
    Math.random()

  robot.bugfixLotto = bugfixLotto = {
    getUsers
    getIssues
    doLotto
    getWeightedOptions
    pickUser
    random
  }

  robot.respond /\s*pick\s*(?:an\s*)?assignee\s*(?:for\s*)?([A-Z0-9\-]+)\s+from\s+([^\s]+)\s*$/, (msg)->
    issueNumber = msg.match[1]
    group = msg.match[2]
    doLotto issueNumber, group, (error, user)->
      if error?
        robot.logger.error error
        msg.reply error.message
        return
      name = user.name
      if typeof robot.convertHandle is 'function'
        name = robot.convertHandle name
      msg.send """
      @#{name} please fix #{issueNumber} :bow:
      https://#{HUBOT_JIRA_DOMAIN}/browse/#{issueNumber}
      """

