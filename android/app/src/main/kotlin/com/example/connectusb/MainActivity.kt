package com.example.connectusb

import android.content.Context
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log
import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/usb"
    private var serialPort: UsbSerialPort? = null
    private var dataStreamingThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Set up the MethodChannel for method calls from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendData" -> {
                    val data = call.argument<ByteArray>("dataToSend") ?: return@setMethodCallHandler
                    sendDataToDevice(data, result)
                }
                "listAvailableDrivers" -> {
                    listAvailableDrivers(result)
                }
                "connectToDevice" -> {
                    connectToDevice(result)
                }
                "disconnect" -> {
                    disconnect(result)
                }
                "stopDataStreaming" -> {
                    stopDataStreaming(result)
                }
                "startDataStreaming" -> {
                    startDataStreaming(result)
                }
                
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.app/stream").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    Log.d("eventSink", "onListen")
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    Log.d("eventSink", "onCancel")
                    eventSink = null
                }
            }
        )
    }



    private fun listAvailableDrivers(result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val usbDefaultProber = UsbSerialProber.getDefaultProber()

        val deviceInfoList = mutableListOf<Map<String, Any?>>()

        for (device in usbManager.deviceList.values) {
            var driver: UsbSerialDriver? = usbDefaultProber.probeDevice(device)

            // Check if the device matches your criteria for using the CdcAcmSerialDriver
            if (driver == null && isA80Device(device)) {
                driver = CdcAcmSerialDriver(device)
            }

            // Check if driver is null and log
            if (driver == null) {
                Log.e("USB_ERROR", "No driver found for device: ${device.productName}")
                continue
            }

            // Check if ports are null or empty and log
            if (driver.ports.isNullOrEmpty()) {
                Log.e("USB_ERROR", "No ports found for device: ${device.productName}")
                continue
            }

     
             val portInfo = mapOf(
                    "deviceName" to device.deviceName,
                    "productName" to device.productName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "deviceId" to device.deviceId,
                    "serialNumber" to device.serialNumber,
                    "driver" to driver.javaClass.simpleName,
                    "portCount" to driver.ports.size,
                )
                deviceInfoList.add(portInfo)
        }

        result.success(deviceInfoList)
    }

    private fun connectToDevice(result: MethodChannel.Result) {
        try {
            val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
            val usbDefaultProber = UsbSerialProber.getDefaultProber()
            val deviceList = usbManager.deviceList
            var targetDevice = deviceList.values.find { it.productName == "A80" }
            if (targetDevice != null) {
                val connection = usbManager.openDevice(targetDevice)
                if (connection == null) {
                    result.error("CONNECTION_FAILED", "Failed to open connection", null)
                    return
                }

                var driver: UsbSerialDriver? = usbDefaultProber.probeDevice(targetDevice)
                if (driver == null && isA80Device(targetDevice)) {
                    driver = CdcAcmSerialDriver(targetDevice)
                }

                try {
                    serialPort = driver?.ports?.get(0)?.apply {
                        open(connection)
                        setParameters(9600, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
                    }
                } catch (e: IOException) {
                    result.error("DEVICE_OPEN", "Failed to open device", null)
                    return
                }

                result.success("Connected to A80 device")
            } else {
                result.error("DEVICE_NOT_FOUND", "A80 device not found", null)
            }
        } catch (e: IOException) {
            result.error("IO_EXCEPTION", "Error in communication", null)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun startDataStreaming(result: MethodChannel.Result) {
        try {
            if (serialPort != null && serialPort!!.isOpen) {
                val buffer = ByteArray(8192)

                val readRunnable = object : Runnable {
                    override fun run() {
                        try {
                            while (!Thread.currentThread().isInterrupted) {
                                val len = serialPort?.read(buffer, 2000) ?: 0
                                if (len > 0) {
                                    val responseData = buffer.copyOf(len)
                                         Log.d("USB_COMM", "Received Steam response: ${responseData.contentToString()}")
                                    try{
                                        runOnUiThread {
                                            eventSink?.success(responseData.contentToString()) 
                                        }
                                        Log.d("sinking", "success sinking response")
                                    }catch (e: IOException) {
                                         Log.d("sinking", "Error sinking response")
                                    }
                                  
                              
                                }
                            }
                        } catch (e: IOException) {
                            Log.e("USB_COMM", "Error reading data: ${e.message}")
                        }
                    }
                }

                // Start a new thread for data streaming
                dataStreamingThread = Thread(readRunnable)
                dataStreamingThread?.start()

                result.success("Started streaming data from device")
            } else {
                result.error("SERIAL_PORT_NOT_FOUND", "Serial port not found", null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun stopDataStreaming(result: MethodChannel.Result) {
        try {
            // Check if the dataStreamingThread is running
            if (dataStreamingThread != null && dataStreamingThread!!.isAlive) {
                // Interrupt the dataStreamingThread to stop data streaming
                dataStreamingThread!!.interrupt()
                dataStreamingThread = null
                result.success("Data streaming stopped")
            } else {
                result.success("No data streaming in progress")
            }
        } catch (e: Exception) {
            result.error("STOP_STREAM_FAILED", "Failed to stop data streaming: ${e.message}", null)
        }
    }



    private fun sendDataToDevice(dataToSend: ByteArray, result: MethodChannel.Result) {
        try {
             if (serialPort == null || !serialPort!!.isOpen) {
                // If the serialPort is null or not open, attempt to connect
                connectToDevice(result)
            }
            if (serialPort != null && serialPort!!.isOpen) {
                try {
                    serialPort?.write(dataToSend, 2000)
                    Log.d("USB_COMM", "Data written to device")
                } catch (e: IOException) {
                    result.error("DEVICE_WRITE", "Failed to write data", null)
                }

            } else {
                result.error("SERIAL_PORT_NOT_FOUND", "Serial port not found", null)
            }
        } catch (e: IOException) {
            result.error("IO_EXCEPTION", "Error in communication", null)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }


    private fun isA80Device(device: UsbDevice): Boolean {
        // You can check vendor ID and product ID to identify the A80 device
        // Replace VENDOR_ID and PRODUCT_ID with the actual values for the A80 device
        val VENDOR_ID = 12216 // Replace with the actual vendor ID
        val PRODUCT_ID = 8661 // Replace with the actual product ID

        return device.vendorId == VENDOR_ID && device.productId == PRODUCT_ID
    }

     private fun disconnect(result: MethodChannel.Result) {
        try {
            serialPort?.close()
            result.success("Disconnected from A80 device")
        } catch (e: IOException) {
            result.error("DISCONNECT_FAILED", "Failed to disconnect", null)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        serialPort?.close()
    }
}
