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

# Returns an array of HN post items
getHackerNewsPosts = (query, callback) ->
  console.log "getHackerNewsPosts: " + query
  limit = 10
  options = 
    host: "api.thriftdb.com"
    path: "/api.hnsearch.com/items/_search?q=" + query + "&" + limit + "=100&weights[title]=2.0&weights[text]=1.5&weights[domain]=1.0&weights[username]=0.0&weights[type]=0.0&boosts[fields][points]=0.15&boosts[fields][num_comments]=0.15&boosts[functions][pow(2,div(div(ms(create_ts,NOW),3600000),72))]=200.0&pretty_print=true"
  console.log "API request to URL: " + options.host + options.path
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
  console.log "id: " + id
  options =
    host: "news.ycombinator.com"
    path: "/item?id=" + id
  https.get options, (res) ->
    data = ''
    res.on 'data', (chunk) ->
      data += chunk
    res.on 'end', ->
      comments = hn.parse(data).comments
      allComments = []
      for comment in comments
        recurseComment allComments, comment
      callback allComments

recurseComment = (comments, comment) ->
  console.log "length: " + comments.length
  comments.push comment.body
  if comment.comments.length > 0
    for c in comment.comments
      recurseComment comments, c



getHackerNewsPosts "bitcoin", (results) ->
  getHackerNewsComments results[0].item.id
  # for result in results
  #   console.log "item[" +_i+"]: " + util.inspect result.item

# Routes
app.get '/', routes.index

http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')
