// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http/io_client.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_proxy/shelf_proxy.dart';

import '../utilities/shared.dart' show LogWriter;
import 'asset_reader.dart';

/// A reader for resources provided by a proxy server.
class ProxyServerAssetReader implements AssetReader {
  final LogWriter _logWriter;

  Handler _handler;

  ProxyServerAssetReader(int assetServerPort, this._logWriter,
      {String root, String host, bool isHttps}) {
    host ??= 'localhost';
    root ??= '';
    isHttps ??= false;
    var scheme = isHttps ? 'https://' : 'http://';
    var client = isHttps
        ? IOClient(
            HttpClient()..badCertificateCallback = (cert, host, port) => true)
        : null;
    var url = '$scheme$host:$assetServerPort/';
    if (root?.isNotEmpty ?? false) url += '$root/';
    _handler = proxyHandler(url, client: client);
  }

  @override
  Future<String> dartSourceContents(String serverPath) =>
      _readResource(serverPath);

  @override
  Future<String> sourceMapContents(String serverPath) =>
      _readResource(serverPath);

  Future<String> _readResource(String path) async {
    // Handlers expect a fully formed HTML URI. The actual hostname and port
    // does not matter.
    var response =
        await _handler(Request('GET', Uri.parse('http://foo:0000/$path')));

    if (response.statusCode != HttpStatus.ok) {
      _logWriter(Level.WARNING, '''
      Failed to load asset at path: $path.

      Status code: ${response.statusCode}

      Headers:
      ${const JsonEncoder.withIndent('  ').convert(response.headers)}
      ''');
      return null;
    } else {
      return await response.readAsString();
    }
  }

  @override
  Future<String> metadataContents(String serverPath) =>
      _readResource(serverPath);
}
