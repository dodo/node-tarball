{ EventEmitter } = require 'events'
zlib = require 'zlib'
tar = require 'tar'


class Extract extends EventEmitter
    constructor: (stream, opts = {}) ->

        @extract = new tar.Extract(opts.path)
            .on('error', @emit.bind(this, 'error'))
        if opts.uncompress
            @extract.pipe(zlib.Gunzip())
                .on('error', @emit.bind(this, 'error'))

        @extract.on('close', opts.done)
        super


module.exports = Extract
