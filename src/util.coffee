{ Stream } = require 'stream'
PostBuffer = require 'bufferstream/postbuffer'

getTime = (d) ->
    date = new Date(d or new Date).getTime() / 1000
    if isNaN(date)
        return new Date().getTime() / 1000
    else
        return date



## this is just needed to please tar
# Emit a whole file at once
class BufferedStream extends Stream

    constructor: (source) ->
        super
        @buffer = new PostBuffer source
        {@props, @root, @path} = source
        @buffer.onEnd (data) =>
            @props.size = data.length
            @emit 'full'
            process.nextTick =>
                @flush data
        @once 'accepted', ->
            source.emit('accepted')

    flush: (body) ->
        @emit 'data', body
        process.nextTick =>
            @emit 'end'

    resume: -> # stub
    pause: -> # stub


module.exports = {
    BufferedStream
    getTime
}
