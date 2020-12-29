package io.github.v7lin.alipay_kit;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.AsyncTask;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.alipay.sdk.app.AuthTask;
import com.alipay.sdk.app.H5PayCallback;
import com.alipay.sdk.app.PayTask;
import com.alipay.sdk.util.H5PayResultModel;

import java.lang.ref.WeakReference;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class AlipayKit implements MethodChannel.MethodCallHandler {
    //

    private static final String METHOD_ISINSTALLED = "isInstalled";
    private static final String METHOD_PAY = "pay";
    private static final String METHOD_PAY_H5 = "payH5";
    private static final String METHOD_PAY_URL_CHANGE = "payUrlChange";
    private static final String METHOD_AUTH = "auth";

    private static final String METHOD_ONPAYRESP = "onPayResp";
    private static final String METHOD_ONAUTHRESP = "onAuthResp";

    private static final String ARGUMENT_KEY_ORDERINFO = "orderInfo";
    private static final String ARGUMENT_KEY_AUTHINFO = "authInfo";
    private static final String ARGUMENT_KEY_ISSHOWLOADING = "isShowLoading";
    private static final String ARGUMENT_KEY_URL = "orderUrl";
    //

    private Context applicationContext;
    private Activity activity;

    private MethodChannel channel;

    public AlipayKit() {
        super();
    }

    public AlipayKit(Context applicationContext, Activity activity) {
        this.applicationContext = applicationContext;
        this.activity = activity;
    }

    //

    public void setApplicationContext(@Nullable Context applicationContext) {
        this.applicationContext = applicationContext;
    }

    public void setActivity(@Nullable Activity activity) {
        this.activity = activity;
    }

    public void startListening(@NonNull BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, "v7lin.github.io/alipay_kit");
        channel.setMethodCallHandler(this);
    }

    public void stopListening() {
        channel.setMethodCallHandler(null);
        channel = null;
    }

    // --- MethodCallHandler

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (METHOD_ISINSTALLED.equals(call.method)) {
            boolean isInstalled = false;
            try {
                final PackageManager packageManager = applicationContext.getPackageManager();
                PackageInfo info = packageManager.getPackageInfo("com.eg.android.AlipayGphone", PackageManager.GET_SIGNATURES);
                isInstalled = info != null;
            } catch (PackageManager.NameNotFoundException e) {
            }
            result.success(isInstalled);
        } else if (METHOD_PAY.equals(call.method)) {
            final String orderInfo = call.argument(ARGUMENT_KEY_ORDERINFO);
            final boolean isShowLoading = call.argument(ARGUMENT_KEY_ISSHOWLOADING);
            final WeakReference<Activity> activityRef = new WeakReference<>(activity);
            final WeakReference<MethodChannel> channelRef = new WeakReference<>(channel);
            new AsyncTask<String, String, Map<String, String>>() {
                @Override
                protected Map<String, String> doInBackground(String... params) {
                    Activity activity = activityRef.get();
                    if (activity != null && !activity.isFinishing()) {
                        PayTask task = new PayTask(activity);
                        return task.payV2(orderInfo, isShowLoading);
                    }
                    return null;
                }

                @Override
                protected void onPostExecute(Map<String, String> result) {
                    if (result != null) {
                        Activity activity = activityRef.get();
                        MethodChannel channel = channelRef.get();
                        if (activity != null && !activity.isFinishing() && channel != null) {
                            channel.invokeMethod(METHOD_ONPAYRESP, result);
                        }
                    }
                }
            }.execute();
            result.success(null);
        } else if( METHOD_PAY_H5.equals(call.method) ){
            final String orderUrl = call.argument(ARGUMENT_KEY_URL);
            final WeakReference<Activity> activityRef = new WeakReference<>(activity);
            final WeakReference<MethodChannel> channelRef = new WeakReference<>(channel);

            final MethodChannel.Result newResult = result;
            PayTask task = new PayTask(activity);
            final String ex = task.fetchOrderInfoFromH5PayUrl(orderUrl);
            Log.e("aaaaaaa",orderUrl + "----------->" + ex);
            task.payInterceptorWithUrl(ex,true, new H5PayCallback() {

                @Override
                public void onPayResult(H5PayResultModel h5PayResultModel) {
                    newResult.success(h5PayResultModel);
                }
            });
//            new AsyncTask<String, String, Map<String, String>>() {
//                @Override
//                protected Map<String, String> doInBackground(String... params) {
//                    Activity activity = activityRef.get();
//                    if (activity != null && !activity.isFinishing()) {
//                        PayTask task = new PayTask(activity);
//                        final String ex = task.fetchOrderInfoFromH5PayUrl(orderUrl);
//                        return task.h5Pay(task,ex,true);
//                    }
//                    return null;
//                }
//
//                @Override
//                protected void onPostExecute(Map<String, String> result) {
//                    if (result != null) {
//                        Activity activity = activityRef.get();
//                        MethodChannel channel = channelRef.get();
//                        if (activity != null && !activity.isFinishing() && channel != null) {
//                            channel.invokeMethod(METHOD_ONPAYRESP, result);
//                        }
//                    }
//                }
//            }.execute();
//            result.success(null);
        } else if (METHOD_AUTH.equals(call.method)) {
            final String authInfo = call.argument(ARGUMENT_KEY_AUTHINFO);
            final boolean isShowLoading = call.argument(ARGUMENT_KEY_ISSHOWLOADING);
            final WeakReference<Activity> activityRef = new WeakReference<>(activity);
            final WeakReference<MethodChannel> channelRef = new WeakReference<>(channel);
            new AsyncTask<String, String, Map<String, String>>(){
                @Override
                protected Map<String, String> doInBackground(String... strings) {
                    Activity activity = activityRef.get();
                    if (activity != null && !activity.isFinishing()) {
                        AuthTask task = new AuthTask(activity);
                        return task.authV2(authInfo, isShowLoading);
                    }
                    return null;
                }

                @Override
                protected void onPostExecute(Map<String, String> result) {
                    if (result != null) {
                        Activity activity = activityRef.get();
                        MethodChannel channel = channelRef.get();
                        if (activity != null && !activity.isFinishing() && channel != null) {
                            channel.invokeMethod(METHOD_ONAUTHRESP, result);
                        }
                    }
                }
            }.execute();
            result.success(null);
        } else {
            result.notImplemented();
        }
    }
}
