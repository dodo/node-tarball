{ EventEmitter } = require 'events'
zlib = require 'zlib'
tar = require 'tar'
{ getTime, BufferedStream, UnbufferedStream } = require './util'


DEFAULTS =
    mode:  0755
    uid:   1000
    gid:   1000
    uname: 'nouser'
    gname: 'nogroup'


class Pack extends EventEmitter
    constructor: (params, opts = {}) ->
        @defaults = {}
        for key, value of DEFAULTS
            @defaults[key] = value
        for key, value of opts.defaults
            @defaults[key] = value

        @on('pipe', @onPipe)
        @pending = []
        @idle = yes

        @pack = @output = new tar.Pack(params)
            .on('error', @onError)
            .on('drain', @onDrain)
        if opts.compress
            @output = @pack.pipe(zlib.Gzip())
                .on('error', @onError)

        @pack.on('close', opts.done) if opts.done?
        super

    onDrain: () =>
        return unless @current?
        return if @current.flushed
        @current?.flushed = yes
        @flush()

    onPipe: (source) =>
        if @idle
            @idle = no
            @current = @check(source)
            @current.once 'full', =>
                @current.flushed = @pack.add(@current)
                if @current.flushed
                    process.nextTick(@flush)
        else
            source.pause()
            @pending.push(source)

    flush: () =>
        old = @current
        next = @pending.shift()
        if next?
            @idle = no
            @current = @check(next)
            @current.once 'full', =>
                @current.flushed = @pack.add(@current)
                @current.resume() unless @current.flushed
                if @current.flushed
                    process.nextTick(@flush)
        else
            @current = null
            @idle = yes
            @end() if @shutdown
        old?.emit('accepted')

    onError: (err) =>
        @emit('error', err)

    append: (stream, callback) ->
        stream.once('accepted', callback) if callback?
        stream.pipe(this, end:no)

    pipe: (source) ->
        @output.pipe(source)

    end: () ->
        if @idle
            @pack.end()
        else
            @shutdown = on

    check: (source) ->
        unless source.path?
            throw new Error "no path"

        source.props ?= {}

        for key, value of @defaults
            source.props[key] ?= value

        if source.props.size?
            if typeof source.props.size isnt 'number'
                source.props.size = parseInt(source.props.size)
            if isNaN(source.props.size)
                source.props.size = undefined

        # autofill size by buffering all
        if source.props.size? and off # FIXME unbuffered doesnt work quite well :/
            stream = new UnbufferedStream(source)
        else
            # No length means we cannot pipe(). tar.Pack
            # needs to know a file's size beforehand though, so we
            # need to buffer the content.
            stream = new BufferedStream(source)

        time = getTime(stream.time)
        stream.props.mtime ?= getTime(stream.props.mtime) ? time
        stream.props.atime ?= getTime(stream.props.atime) ? time
        stream.props.ctime ?= getTime(stream.props.ctime) ? time

        stream.props.path ?= stream.path
        (stream.root ?= {}).path = "."

        return stream


module.exports = Pack
