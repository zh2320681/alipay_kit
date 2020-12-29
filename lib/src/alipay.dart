import 'dart:async';
import 'dart:convert';

import 'package:alipay_kit/src/crypto/rsa.dart';
import 'package:alipay_kit/src/model/alipay_resp.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

///
class Alipay {
  ///
  Alipay() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  static const String _METHOD_ISINSTALLED = 'isInstalled';
  static const String _METHOD_PAY = 'pay';
  static const String _METHOD_AUTH = 'auth';
  static final String _METHOD_PAY_H5 = "payH5";

  static const String _METHOD_ONPAYRESP = 'onPayResp';
  static const String _METHOD_ONAUTHRESP = 'onAuthResp';

  static const String _ARGUMENT_KEY_ORDERINFO = 'orderInfo';
  static const String _ARGUMENT_KEY_AUTHINFO = 'authInfo';
  static const String _ARGUMENT_KEY_ISSHOWLOADING = 'isShowLoading';
  static final String ARGUMENT_KEY_URL = "orderUrl";

  static const String SIGNTYPE_RSA = 'RSA';
  static const String SIGNTYPE_RSA2 = 'RSA2';

  static const String AUTHTYPE_AUTHACCOUNT = 'AUTHACCOUNT';
  static const String AUTHTYPE_LOGIN = 'LOGIN';

  final MethodChannel _channel =
      const MethodChannel('v7lin.github.io/alipay_kit');

  final StreamController<AlipayResp> _payRespStreamController =
      StreamController<AlipayResp>.broadcast();
  final StreamController<AlipayResp> _authRespStreamController =
      StreamController<AlipayResp>.broadcast();

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case _METHOD_ONPAYRESP:
        _payRespStreamController
            .add(AlipayResp.fromJson(call.arguments as Map<dynamic, dynamic>));
        break;
      case _METHOD_ONAUTHRESP:
        _authRespStreamController
            .add(AlipayResp.fromJson(call.arguments as Map<dynamic, dynamic>));
        break;
    }
  }

  /// 支付
  Stream<AlipayResp> payResp() {
    return _payRespStreamController.stream;
  }

  /// 登录
  Stream<AlipayResp> authResp() {
    return _authRespStreamController.stream;
  }

  /// 检测支付宝是否已安装
  Future<bool> isInstalled() {
    return _channel.invokeMethod<bool>(_METHOD_ISINSTALLED);
  }

  /// 支付
  Future<void> payOrderJson({
    @required String orderInfo,
    String signType = SIGNTYPE_RSA2,
    @required String privateKey,
    bool isShowLoading = true,
  }) {
    assert(orderInfo?.isNotEmpty ?? false);
    assert(privateKey?.isNotEmpty ?? false);
    return payOrderMap(
      orderInfo: json.decode(orderInfo) as Map<String, dynamic>,
      signType: signType,
      privateKey: privateKey,
      isShowLoading: isShowLoading,
    );
  }

  /// 支付
  Future<void> payOrderMap({
    @required Map<String, dynamic> orderInfo,
    String signType = SIGNTYPE_RSA2,
    @required String privateKey,
    bool isShowLoading = true,
  }) {
    assert(orderInfo?.isNotEmpty ?? false);
    assert(privateKey?.isNotEmpty ?? false);
    String charset = orderInfo['charset'] as String;
    Encoding encoding =
        (charset?.isNotEmpty ?? false) ? Encoding.getByName(charset) : null;
    encoding ??= utf8;
    Map<String, dynamic> clone = <String, dynamic>{
      ...orderInfo,
      'sign_type': signType,
    };
    String param = _param(clone, encoding);
    String sign = _sign(clone, signType, privateKey);
    return payOrderSign(
      orderInfo:
          '$param&sign=${Uri.encodeQueryComponent(sign, encoding: encoding)}',
      isShowLoading: isShowLoading,
    );
  }

  /// 支付
  Future<void> payOrderSign({
    @required String orderInfo,
    bool isShowLoading = true,
  }) {
    assert(orderInfo?.isNotEmpty ?? false);
    return _channel.invokeMethod<void>(
      _METHOD_PAY,
      <String, dynamic>{
        _ARGUMENT_KEY_ORDERINFO: orderInfo,
        _ARGUMENT_KEY_ISSHOWLOADING: isShowLoading,
      },
    );
  }

  Future<Map<String,dynamic>> payH5(@required String orderUrl){
    assert(orderUrl?.isNotEmpty ?? false);
    return _channel.invokeMethod<Map<String,dynamic>>(_METHOD_PAY_H5,<String, dynamic>{ARGUMENT_KEY_URL : orderUrl} );
  }

  /// 登录
  Future<void> auth({
    @required String appId, // 支付宝分配给开发者的应用ID
    @required String pid, // 签约的支付宝账号对应的支付宝唯一用户号，以2088开头的16位纯数字组成
    @required String targetId, // 商户标识该次用户授权请求的ID，该值在商户端应保持唯一
    String authType =
        AUTHTYPE_AUTHACCOUNT, // 标识授权类型，取值范围：AUTHACCOUNT 代表授权；LOGIN 代表登录
    String signType =
        SIGNTYPE_RSA2, // 商户生成签名字符串所使用的签名算法类型，目前支持 RSA2 和 RSA ，推荐使用 RSA2
    @required String privateKey,
    bool isShowLoading = true,
  }) {
    assert((appId?.isNotEmpty ?? false) && appId.length <= 16);
    assert((pid?.isNotEmpty ?? false) && pid.length <= 16);
    assert((targetId?.isNotEmpty ?? false) && targetId.length <= 32);
    assert(authType == AUTHTYPE_AUTHACCOUNT || authType == AUTHTYPE_LOGIN);
    assert(privateKey?.isNotEmpty ?? false);
    Map<String, dynamic> authInfo = <String, dynamic>{
      'apiname': 'com.alipay.account.auth',
      'method': 'alipay.open.auth.sdk.code.get',
      'app_id': appId,
      'app_name': 'mc',
      'biz_type': 'openservice',
      'pid': pid,
      'product_id': 'APP_FAST_LOGIN',
      'scope': 'kuaijie',
      'target_id': targetId,
      'auth_type': authType,
    };
    authInfo['sign_type'] = signType;
    Encoding encoding = utf8; // utf-8
    String param = _param(authInfo, encoding);
    String sign = _sign(authInfo, signType, privateKey);
    return authSign(
      info: '$param&sign=${Uri.encodeQueryComponent(sign, encoding: encoding)}',
      isShowLoading: isShowLoading,
    );
  }

  /// 登录
  Future<void> authSign({
    @required String info,
    bool isShowLoading = true,
  }) {
    assert(info != null && info.isNotEmpty);
    return _channel.invokeMethod<void>(
      _METHOD_AUTH,
      <String, dynamic>{
        _ARGUMENT_KEY_AUTHINFO: info,
        _ARGUMENT_KEY_ISSHOWLOADING: isShowLoading,
      },
    );
  }

  String _param(Map<String, dynamic> map, Encoding encoding) {
    return map.entries
        .map((MapEntry<String, dynamic> e) =>
            '${e.key}=${Uri.encodeQueryComponent('${e.value}', encoding: encoding)}')
        .join('&');
  }

  String _sign(Map<String, dynamic> map, String signType, String privateKey) {
    // 参数排序
    List<String> keys = map.keys.toList();
    keys.sort();
    String content = keys.map((String e) => '$e=${map[e]}').join('&');
    String sign;
    switch (signType) {
      case SIGNTYPE_RSA:
        sign = base64
            .encode(RsaSigner.sha1Rsa(privateKey).sign(utf8.encode(content)));
        break;
      case SIGNTYPE_RSA2:
        sign = base64
            .encode(RsaSigner.sha256Rsa(privateKey).sign(utf8.encode(content)));
        break;
      default:
        throw UnsupportedError('Alipay sign_type($signType) is not supported!');
    }
    return sign;
  }
}
