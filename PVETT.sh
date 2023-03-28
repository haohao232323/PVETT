#!/usr/bin/env python3
import os
import time
import json
import requests
import urllib.parse
import base64
def check_dependencies():
    """
    检查依赖包是否已安装，如果没有安装则安装
    """
    dependencies = ['lm-sensors', 'curl']
    for dep in dependencies:
        if os.system(f"dpkg -s {dep} >/dev/null 2>&1") != 0:
            os.system(f"apt-get install -y {dep}")
def check_temperature(threshold):
    """
    检查CPU温度是否高于设定的阈值
    """
    temperature = int(os.popen("sensors | grep 'Core 0' | awk '{print $3}' | cut -c2-3").read())
    if temperature > threshold:
        return f"CPU温度过高：{temperature}℃"
    return None
def check_loadavg(threshold):
    """
    检查1分钟负载是否超过阈值
    """
    loadavg = os.getloadavg()[0]
    if loadavg > threshold:
        return f"1分钟负载过高：{loadavg}"
    return None
def check_memusage(threshold):
    """
    检查内存占用是否超过阈值
    """
    meminfo = os.popen("cat /proc/meminfo | grep MemAvailable").read()
    mem_available = int(meminfo.split()[1])
    mem_total = int(os.popen("cat /proc/meminfo | grep MemTotal").read().split()[1])
    memusage = (mem_total - mem_available) / mem_total
    if memusage > threshold:
        return f"内存占用过高：{memusage*100:.2f}%"
    return None
def check_vmstatus():
    """
    检查虚拟机状态是否正常
    """
    error_vm_list = []
    vmlist = json.loads(os.popen("pvesh get /cluster/resources --type vm").read())
    for vm in vmlist:
        if vm["status"] != "running":
            error_vm_list.append(vm["name"])
    if error_vm_list:
        return f"虚拟机意外关机：{','.join(error_vm_list)}"
    return None
def send_dingtalk_message(access_token, secret, message):
    """
    发送钉钉消息
    """
    timestamp = str(round(time.time() * 1000))
    secret_enc = secret.encode('utf-8')
    string_to_sign = f"{timestamp}\n{secret}"
    string_to_sign_enc = string_to_sign.encode('utf-8')
    import hmac
    import hashlib
    hmac_code = hmac.new(secret_enc, string_to_sign_enc, digestmod=hashlib.sha256).digest()
    sign = urllib.parse.quote_plus(base64.b64encode(hmac_code))
    url = f"https://oapi.dingtalk.com/robot/send?access_token={access_token}&timestamp={timestamp}&sign={sign}"
    headers = {'Content-Type': 'application/json;charset=utf-8'}
    data = {
        "msgtype": "text",
        "text": {
            "content": message
        }
    }
    requests.post(url=url, headers=headers, data=json.dumps(data))
def send_bark_message(bark_url, message):
    """
    发送Bark消息
    """
    url = f"{bark_url}/{urllib.parse.quote_plus(message)}"
    requests.get(url=url)
def get_send_channel():
    """
    获取用户选择的发送通道
    """
    while True:
        channel = input("请选择发送通道（1：钉钉；2：Bark）：")
        if channel == "1":
            return "dingtalk"
        elif channel == "2":
            return "bark"
        else:
            print("输入错误，请重新选择。")
def send_message(send_channel, access_token, secret, bark_url, message):
    """
    发送消息到指定的发送通道
    """
    if send_channel == "dingtalk":
        send_dingtalk_message(access_token, secret, message)
    elif send_channel == "bark":
        send_bark_message(bark_url, message)
def main():
    # 读取用户设定的阈值
    temperature_threshold = int(input("请输入CPU温度阈值："))
    loadavg_threshold = float(input("请输入1分钟负载阈值："))
    memusage_threshold = float(input("请输入内存占用阈值："))
    # 检查依赖包是否已安装
    check_dependencies()
    # 检查服务器状态
    message_list = []
    temperature_message = check_temperature(temperature_threshold)
    if temperature_message:
        message_list.append(temperature_message)
    loadavg_message = check_loadavg(loadavg_threshold)
    if loadavg_message:
        message_list.append(loadavg_message)
    memusage_message = check_memusage(memusage_threshold)
    if memusage_message:
        message_list.append(memusage_message)
    vmstatus_message = check_vmstatus()
    if vmstatus_message:
        message_list.append(vmstatus_message)
    # 如果有异常则发送消息
    if message_list:
        send_channel = get_send_channel()
        if send_channel == "dingtalk":
            access_token = input("请输入钉钉机器人的access_token：")
            secret = input("请输入钉钉机器人的secret：")
            send_message(send_channel, access_token, secret, None, "\n".join(message_list))
        elif send_channel == "bark":
            bark_url = input("请输入Bark的URL：")
            send_message(send_channel, None, None, bark_url, "\n".join(message_list))
    else:
        print("服务器状态正常。")
if __name__ == "__main__":
    try:
        main()
        print("配置成功，已发送服务器状态到所选择的通道。")
    except Exception as e:
        print(f"配置失败，错误信息：{e}，请检查错误的位置。")
