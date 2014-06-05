###
# Module dependencies.
###

express = require 'express'
routes = require './routes'
http = require 'http'
path = require 'path'
util = require 'util'
sentiment = require 'sentiment'
hn = require 'hacker-news-parser'
https = require 'https'
request = require 'request'
WebSocketServer = require('ws').Server
grunt = require 'grunt'
compressor = require 'node-minify'
async = require 'async'
_ = require 'underscore'

require 'newrelic'


# Grunt task
grunt.loadNpmTasks 'grunt-contrib-coffee'
grunt.tasks [], {}, ->
  grunt.log.ok "Grunt: Done running tasks!"

new compressor.minify {
  type: 'uglifyjs',
  fileIn: 'assets/js/client.js',
  fileOut: 'public/js/client.min.js',
  callback: (err) ->  if err
    console.log 'minify: ' + err
  }

# Express
app = express()

# all environments
app.set 'port', process.env.PORT || 3000
app.set 'views', path.join __dirname, 'views'
app.set 'view engine', 'jade'
app.use express.favicon()
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use app.router
app.use express.static path.join __dirname, 'public'

# development only
if app.get('env') is 'development'
  app.use express.logger 'dev'
  app.use express.errorHandler()
  app.locals.pretty = true

server = http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')

wss = new WebSocketServer({server:server})

cache = {}

# Returns an array of HN post items
getHackerNewsPosts = (query, callback) ->
  console.log "getHackerNewsPosts: " + query
  query = 'http://hn.algolia.com/api/v1/search?query=' + query + '&tags=story'
  console.log "API request to URL: " + query

  request.get query, (err, res, body) ->
    util.inspect err if err
    callback JSON.parse(res.body).hits
  .on 'error', (e) ->
    console.log "Got error: " + e.message

getHackerNewsComments = (id, callback) ->
  comments = []
  options =
    host: "news.ycombinator.com"
    path: "/item?id=" + id

  console.log "Post: https://" + options.host+options.path

  request "https://"+options.host+options.path, (err, res, body) ->
    console.log "request ERR: "+ util.inspect err if err
    allComments = []
    try
      comments = hn.parse(body).comments
    catch error
      console.log "Parsing Comments Err: " + error
      callback allComments
      return
    for comment in comments
      recurseComment allComments, comment
    callback allComments

recurseComment = (comments, comment) ->
  comments.push comment.body
  if comment.comments.length > 0
    for c in comment.comments
      recurseComment comments, c


parseResult = (result, callback) ->
  allText = []
  allText.push result.title
  if result.story_text
    allText.push result.story_text
  getHackerNewsComments result.objectID, (allComments) ->
    console.log 'comments'
    console.log allComments
    allText = allText.concat allComments if allComments.length > 0


wss.on 'connection', (ws) ->
  console.log "clientConnection"
  ws.on 'message' , (msg) ->
    # console.log "wss received: " + msg
    msg = JSON.parse msg
    handleMSG msg.text, (msg) ->
      ws.send JSON.stringify msg

handleMSG = (query, callback) ->
  query = query.toLowerCase()
  if cache[query]
    # caching
    callback cache[query]
    return
  getHackerNewsPosts query, (results) ->
    async.map results, (result, callback) ->
      parseResult result, (text)->
        callback null, text
    ,(err, results)->
      async.map results, (result, callback) ->
        sentiment _.flatten(result).join(' '), (err, res)->
          callback err if err
          callback null, res
      ,(err, results)->
        score = 0
        count = results.length
        console.dir 'count: ' + count
        # Hackey workaround for garbage from sentiment... :\
        for res in results
          if isNaN res.score
            res.score = res.score.replace(/function.*/, '')
          score += parseInt res.score
        console.log score
        opinionIndex = Math.ceil score / count
        positiveWords = res.positive
        negativeWords = res.negative

        console.log "Opinion: " + opinionIndex
        # console.log "Positive Words: " + positiveWords
        # console.log "Negative Words: " + negativeWords
        msg = if isNaN opinionIndex then opinion:"Error analyzing user sentiment..." else opinion: opinionIndex
        cache[query] = msg
        callback msg


# Routes
app.get '/', routes.index
