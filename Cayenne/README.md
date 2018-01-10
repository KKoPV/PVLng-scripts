# PVLng to Cayenne

The logic is adapted from
[Cayenne-MQTT-Python client](https://github.com/myDevicesIoT/Cayenne-MQTT-Python/blob/master/cayenne/client.py)
and was ported to pure bash.

## Install mosquitto clients

    sudo apt-get update
    sudo apt-get -y install mosquitto-clients

## Add Device on Cayenne

Go to your [Cayenne dashboard](https://cayenne.mydevices.com/cayenne/dashboard) and
**Add new ...** > **Device/Widget**

Use **CAYENNE API** > **Bring Your Own Thing**

Remember your **username**, **password** and **client id**

> Note: The **username** and **password** is unique for your account,
the **client id** is different for each device.

## Configure

    cp dist/cayenne.conf .

Fill your credentials and channels.

Find the correct datatye and unit for your channels in `datatypes.sh`.
