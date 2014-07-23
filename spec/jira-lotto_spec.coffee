path = require 'path'
fs = require 'fs'
# Hubot classes
Robot = require "hubot/src/robot"
{ TextMessage } = require "hubot/src/message"

# Load assertion methods to this scope
chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'
nock = require 'nock'
{ expect } = chai

fixtureJSON = (name)->
  JSON.parse fs.readFileSync path.resolve(__dirname, 'fixtures', "#{name}.json"), 'utf8'

describe 'bugfixer-lotto', ->
  robot = null
  user = null
  adapter = null
  beforeEach ->
    nock.disableNetConnect()
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    user = robot.brain.userForId '1', {
      name: 'ngs'
      room: '#mocha'
    }
    adapter = robot.adapter
    nockScope = nock('https://bugfix-hubot-test.myjira.tld')
      .filteringRequestBody(/.*/, '*')
      .get('/rest/api/2/group?groupname=bugfixers&expand=users')
      .replyWithFile(200, path.resolve(__dirname, 'fixtures', "users.json"))
      .post('/rest/api/2/search', '*')
      .replyWithFile(200, path.resolve(__dirname, 'fixtures', "issues.json"))
      .put('/rest/api/2/issue/BUGS-32/assignee', '*')
      .reply(204, '')

  afterEach ->
    delete process.env.HUBOT_JIRA_DOMAIN
    delete process.env.HUBOT_JIRA_LOGIN
    delete process.env.HUBOT_JIRA_PASSWORD
    robot.server.close()
    nock.cleanAll()
    robot.shutdown()
    process.removeAllListeners 'uncaughtException'

  describe 'missing parameters', ->
    it 'should log error', (done)->
      sinon.spy robot.logger, 'error'
      robot.adapter.on 'connected', ->
        try
          robot.loadFile path.resolve(__dirname, '..', 'src', 'scripts'), 'jira-lotto.coffee'
          expect(robot.logger.error).to.have.been.calledWith """
          Required configurations are missing: HUBOT_JIRA_DOMAIN, HUBOT_JIRA_LOGIN, HUBOT_JIRA_PASSWORD
          """
          do done
        catch e
          done e

      do robot.run

  describe 'satisfied requirement', ->
    beforeEach (done)->
      process.env.HUBOT_BUGFIXER_GROUP = 'bugfixers'
      process.env.HUBOT_JIRA_DOMAIN = 'bugfix-hubot-test.myjira.tld'
      process.env.HUBOT_JIRA_LOGIN = 'jira'
      process.env.HUBOT_JIRA_PASSWORD = 'password'
      robot.adapter.on 'connected', ->
        robot.loadFile path.resolve(__dirname, '..', 'src', 'scripts'), 'jira-lotto.coffee'
        hubotScripts = path.resolve 'node_modules', 'hubot', 'src', 'scripts'
        robot.loadFile hubotScripts, 'help.coffee'
        do waitForHelp = ->
          if robot.helpCommands().length > 0
            do done
          else
            setTimeout waitForHelp, 100
      do robot.run

    describe 'help', ->
      it 'should have 3', (done)->
        expect(robot.helpCommands()).to.have.length 3
        do done

      it 'should parse help', (done)->
        adapter.on 'send', (envelope, strings)->
          ## Prefix bug with parseHelp
          ## https://github.com/github/hubot/pull/712
          try
            expect(strings).to.deep.equal ["""
            TestTestHubot help - Displays all of the help commands that TestHubot knows about.
            TestTestHubot help <query> - Displays all help commands that match <query>.
            TestTestHubot pick (an) assignee (for) <ISSUE-NUMBER> from <ASSIGNEE-GROUP> - Pick an assignee for JIRA issues.
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'TestHubot help'

    describe 'bugfixLotto', ->
      describe 'general', ->
        it 'should be assigned to the robot', ->
          expect(robot.bugfixLotto).to.be.defined
      describe 'getWeightedOptions', ->
        it 'should return weighted options', ->
          users  = fixtureJSON('users').users.items
          issues = fixtureJSON('issues').issues
          issueNumber = 'BUGS-32'
          res = robot.bugfixLotto.getWeightedOptions { users, issues, issueNumber }
          total = 411
          expect(res).to.deep.equal {
            user01: 34 / total
            user02: 32 / total
            user03: 40 / total
            user04: 37 / total
            user05: 37 / total
            user06: 38 / total
            user07: 38 / total
            user08: 38 / total
            user09: 40 / total
            user10: 36 / total
            user11: 41 / total
          }
      describe 'pickUser', ->
        users  = fixtureJSON('users').users.items
        issues = fixtureJSON('issues').issues
        issueNumber = 'BUGS-32'
        random = 0.0
        beforeEach ->
          sinon.stub robot.bugfixLotto, 'random', -> random
        afterEach ->
          robot.bugfixLotto.random.restore()
        expects = [
          'user01'
          'user01'
          'user02'
          'user02'
          'user03'
          'user04'
          'user04'
          'user05'
          'user05'
          'user06'
          'user06'
          'user07'
          'user08'
          'user08'
          'user09'
          'user09'
          'user10'
          'user10'
          'user11'
          'user11'
        ]
        expects.forEach (user, i)->
          it "should pick a user (#{i})", ->
            random = if i == 0 then i else i/(expects.length-1)
            u = robot.bugfixLotto.pickUser { users, issues, issueNumber }
            expect(u.name).to.equal user

      describe 'doLotto', ->
        it 'should pick a user', (done)->
          sinon.stub robot.bugfixLotto, 'random', -> 0.5
          robot.bugfixLotto.doLotto 'BUGS-32', 'bugfixers', (error, user)->
            try
              expect(error).to.be.a 'null'
              expect(user).to.deep.equal
                avatarUrls:
                  "16x16": "https://hubot-bugfix-test.myjira.tld/useravatar/06?size=xsmall"
                  "24x24": "https://hubot-bugfix-test.myjira.tld/useravatar/06?size=small"
                  "32x32": "https://hubot-bugfix-test.myjira.tld/useravatar/06?size=medium"
                  "48x48": "https://hubot-bugfix-test.myjira.tld/useravatar/06"
                emailAddress: "user06@ourcompany.tld"
                name: "user06"
              do done
            catch e
              done e

    describe 'response', ->
      [
        'TestHubot  pick  an  assignee  BUGS-32  from  bugfixers'
      ].forEach (msg)->
        it "should respond to #{msg}", (done)->
          sinon.stub robot.bugfixLotto, 'random', -> 0.5
          robot.convertHandle = (handle)->
            "local-#{handle}"
          adapter.on 'send', (envelope, strings)->
            try
              expect(strings).to.deep.equal [
                """
                @local-user06 please fix BUGS-32 :bow:
                https://bugfix-hubot-test.myjira.tld/browse/BUGS-32
                """]
              do done
            catch e
              done e
          adapter.receive new TextMessage user, msg

