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
  limit = 10
  options =
    host: "api.thriftdb.com"
    path: "/api.hnsearch.com/items/_search?q=" + query + "&" + limit + "=100&weights[title]=2.0&weights[text]=1.5&weights[domain]=1.0&weights[username]=0.0&weights[type]=0.0&boosts[fields][points]=0.15&boosts[fields][num_comments]=0.15&boosts[functions][pow(2,div(div(ms(create_ts,NOW),3600000),72))]=200.0&pretty_print=true"
  # console.log "API request to URL: " + options.host + options.path
  http.get options, (res) ->
    data = ''
    res.on 'data', (chunk) ->
      data += chunk
    res.on 'end', ->
      callback JSON.parse(data).results
  .on 'error', (e) ->
    console.log "Got error: " + e.message

getHackerNewsComments = (id, callback) ->
  comments = []
  options =
    host: "news.ycombinator.com"
    path: "/item?id=" + id

  # console.log "Post: https://" + options.host+options.path
  request "https://"+options.host+options.path, (err, res) ->
  # request "https://news.ycombinator.com/item?id=4992617", (err, res) ->
    console.log "request ERR: "+ util.inspect err if err

    allComments = []
    try
      comments = hn.parse(res.body).comments
    catch error
      console.log error
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
  allText.push result.item.title
  if result.item.text
    allText.push result.item.text
  # console.log "allText: " + allText
  getHackerNewsComments result.item.id, (allComments) ->
    callback allComments.concat allText

sentimentalize = (textArray, callback) ->
  opinionIndex = 0
  i = 0
  positiveWords = []
  negativeWords = []
  for text in textArray
    if !text
      i++
    else
      sentiment text, (err, res) ->
        console.log err if err
        opinionIndex += res.score
        positiveWords = positiveWords.concat res.positive
        negativeWords = negativeWords.concat res.negative
        if ++i is textArray.length
          callback opinionIndex, positiveWords, negativeWords


wss.on 'connection', (ws) ->
  console.log "clientConnection"
  ws.on 'message' , (msg) ->
    # console.log "wss received: " + msg
    msg = JSON.parse msg
    handleMSG msg.text, (msg) ->
      ws.send JSON.stringify msg
      # ws.send opinion ##TODO

handleMSG = (query, callback) ->
  query = query.toLowerCase()
  if cache[query]
    # console.dir cache
    callback cache[query]
    return
  getHackerNewsPosts query, (results) ->
  # results.splice 5 # temp limit
    article = []
    sent = []
    i=0
    for result in results
      parseResult result, (text) ->
        sent = sent.concat text
        # console.log "i:"+i+" results.length:"+results.length
        if ++i is results.length
          # console.log "sent length: " + sent.length
          sentimentalize sent, (opinionIndex, posWords, negWords) ->
            console.log "Opinion: " + opinionIndex
            msg =
              opinion: opinionIndex
            cache[query] = msg
            callback msg
          # console.log "Positive Words: " + posWords
          # console.log "Negative Words: " + negWords



# Split sentences
# var sentences = str.replace(/\.\s+/g,'.|').replace(/\?\s/g,'?|').replace(/\!\s/g,'!|').split("|");
# Routes
app.get '/', routes.index

