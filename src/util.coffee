{ Stream } = require 'stream'
PostBuffer = require 'bufferstream/postbuffer'

getTime = (d) ->
    date = new Date(d or new Date).getTime() / 1000
    if isNaN(date)
        return new Date().getTime() / 1000
    else
        return date


class UnbufferedStream extends Stream
    constructor: (source) ->
        super
        @closed = no
        {@props, @root, @path} = source
        source.once 'end', =>
        @once 'accepted', ->
            source.emit('accepted')
        source.pipe(this)

    end: ->
        @emit 'full'
        process.nextTick =>
            @emit 'end'
            @closed = yes

    resume: -> # stub
    pause: -> # stub

## this is just needed to please tar
# Emit a whole file at once
class BufferedStream extends Stream

    constructor: (source) ->
        super
        @closed = no
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
            @closed = yes
            @emit 'end'

    resume: -> # stub
    pause: -> # stub


module.exports = {
    UnbufferedStream
    BufferedStream
    getTime
}
