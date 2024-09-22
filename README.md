# 使用方法：

## Debian 11：

### 下载 ray-install.sh：

```
curl -L https://github.com/IRN-Kawakaze/install-ray-and-manage-log/raw/main/ray-install.sh > ray-install.sh && \
echo 'a973f4e46d63880ddd2f71e9c6ab379ced763006af67e78d2b835f5561c1d84b  ray-install.sh' | sha256sum -c -
```

##### 安装 V2Ray-core（v2ray 参数可缩写为：v2）：
```
bash ray-install.sh v2ray install
```

##### 安装 Xray-core（xray 参数可缩写为：x）：
```
bash ray-install.sh xray install
```

##### 将 Xray-core 的 geoip.dat 替换为基于 IPinfo 的 geoip.dat：
```
bash ray-install.sh xray ipinfo
```

