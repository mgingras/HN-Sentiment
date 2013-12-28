ws = undefined
escapable = /[\x00-\x1f\ud800-\udfff\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufff0-\uffff]/g

filterUnicode = (quoted) ->
  escapable.lastIndex = 0
  return quoted  unless escapable.test(quoted)
  quoted.replace escapable, (a) ->
    ""

$(document).ready ->
  host = location.origin.replace /^http/, 'ws'
  ws =  new WebSocket host
  $("#myForm").submit (e) ->
   e.preventDefault()

  $('#submit').on "click", ->
    text= $("#inText").val()
    # console.log text
    # text = filterUnicode text
    # console.log text

    text = text.replace(/\s/g, '');
    text = decodeURIComponent text
    msg = 
      type: "message"
      text: text
    msg = JSON.stringify msg
    # console.log msg
    # filterUnicode msg
    # console.log msg
    ws.send msg