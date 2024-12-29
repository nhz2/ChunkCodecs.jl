# Release Notes

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Unreleased

## [v0.2.0](https://github.com/nhz2/ChunkCodecs.jl/tree/ChunkCodecCore-v0.2.0) - 2024-12-29

### BREAKING `try_resize_decode!`'s signature is changed. [#5](https://github.com/nhz2/ChunkCodecs.jl/pull/5)

`max_size` is a required positional argument instead of an optional keyword argument.

### Fixed

- When using a `Codec` as a decoder the `max_size` option was ignored. [#5](https://github.com/nhz2/ChunkCodecs.jl/pull/5)

## [v0.1.1](https://github.com/nhz2/ChunkCodecs.jl/tree/ChunkCodecCore-v0.1.1) - 2024-12-20

### Added

- Initial release
