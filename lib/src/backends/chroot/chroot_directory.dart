// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of file.src.backends.chroot;

class _ChrootDirectory extends _ChrootFileSystemEntity<Directory, io.Directory>
    with ForwardingDirectory {
  factory _ChrootDirectory.wrapped(
    ChrootFileSystem fs,
    Directory delegate, {
    bool relative: false,
  }) {
    String localPath = fs._local(delegate.path, relative: relative);
    return new _ChrootDirectory(fs, localPath);
  }

  _ChrootDirectory(ChrootFileSystem fs, String path) : super(fs, path);

  @override
  FileSystemEntityType get expectedType => FileSystemEntityType.DIRECTORY;

  @override
  io.Directory _rawDelegate(String path) => fileSystem.delegate.directory(path);

  @override
  Uri get uri => new Uri.directory(path);

  @override
  Future<Directory> rename(String newPath) async {
    if (_isLink) {
      if (await fileSystem.type(path) != expectedType) {
        throw new FileSystemException('Not a directory', path);
      }
      FileSystemEntityType type = await fileSystem.type(newPath);
      if (type != FileSystemEntityType.NOT_FOUND) {
        if (type != expectedType) {
          throw new FileSystemException('Not a directory', newPath);
        }
        if (!(await fileSystem
            .directory(newPath)
            .list(followLinks: false)
            .isEmpty)) {
          throw new FileSystemException('Directory not empty', newPath);
        }
      }
      String target = await fileSystem.link(path).target();
      await fileSystem.link(path).delete();
      await fileSystem.link(newPath).create(target);
      return fileSystem.directory(newPath);
    } else {
      return wrap(await getDelegate(followLinks: true)
          .rename(fileSystem._real(newPath)));
    }
  }

  @override
  Directory renameSync(String newPath) {
    if (_isLink) {
      if (fileSystem.typeSync(path) != expectedType) {
        throw new FileSystemException('Not a directory', path);
      }
      FileSystemEntityType type = fileSystem.typeSync(newPath);
      if (type != FileSystemEntityType.NOT_FOUND) {
        if (type != expectedType) {
          throw new FileSystemException('Not a directory', newPath);
        }
        if (fileSystem
            .directory(newPath)
            .listSync(followLinks: false)
            .isNotEmpty) {
          throw new FileSystemException('Directory not empty', newPath);
        }
      }
      String target = fileSystem.link(path).targetSync();
      fileSystem.link(path).deleteSync();
      fileSystem.link(newPath).createSync(target);
      return fileSystem.directory(newPath);
    } else {
      return wrap(
          getDelegate(followLinks: true).renameSync(fileSystem._real(newPath)));
    }
  }

  @override
  Directory get absolute => new _ChrootDirectory(fileSystem, _absolutePath);

  @override
  Directory get parent {
    try {
      return wrapDirectory(delegate.parent);
    } on _ChrootJailException {
      return this;
    }
  }

  @override
  Future<Directory> create({bool recursive: false}) async {
    if (_isLink) {
      switch (await fileSystem.type(path)) {
        case FileSystemEntityType.NOT_FOUND:
          throw new FileSystemException('No such file or directory', path);
        case FileSystemEntityType.FILE:
          throw new FileSystemException('File exists', path);
        case FileSystemEntityType.DIRECTORY:
          // Nothing to do.
          return this;
        default:
          throw new AssertionError();
      }
    } else {
      return wrap(await delegate.create(recursive: recursive));
    }
  }

  @override
  void createSync({bool recursive: false}) {
    if (_isLink) {
      switch (fileSystem.typeSync(path)) {
        case FileSystemEntityType.NOT_FOUND:
          throw new FileSystemException('No such file or directory', path);
        case FileSystemEntityType.FILE:
          throw new FileSystemException('File exists', path);
        case FileSystemEntityType.DIRECTORY:
          // Nothing to do.
          return;
        default:
          throw new AssertionError();
      }
    } else {
      delegate.createSync(recursive: recursive);
    }
  }

  @override
  Stream<FileSystemEntity> list({
    bool recursive: false,
    bool followLinks: true,
  }) {
    Directory delegate = this.delegate;
    String dirname = delegate.path;
    return delegate
        .list(recursive: recursive, followLinks: followLinks)
        .map((io.FileSystemEntity entity) => _denormalize(entity, dirname));
  }

  @override
  List<FileSystemEntity> listSync({
    bool recursive: false,
    bool followLinks: true,
  }) {
    Directory delegate = this.delegate;
    String dirname = delegate.path;
    return delegate
        .listSync(recursive: recursive, followLinks: followLinks)
        .map((io.FileSystemEntity entity) => _denormalize(entity, dirname))
        .toList();
  }

  FileSystemEntity _denormalize(io.FileSystemEntity entity, String dirname) {
    p.Context ctx = fileSystem._context;
    String relativePart = ctx.relative(entity.path, from: dirname);
    String entityPath = ctx.join(path, relativePart);
    if (entity is io.File) {
      return new _ChrootFile(fileSystem, entityPath);
    } else if (entity is io.Directory) {
      return new _ChrootDirectory(fileSystem, entityPath);
    } else if (entity is io.Link) {
      return new _ChrootLink(fileSystem, entityPath);
    }
    throw new FileSystemException('Unsupported type: $entity', entity.path);
  }
}
