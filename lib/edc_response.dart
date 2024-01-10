import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:connectusb/edc_field_element.dart';

class EDCResponse {
  final int PRESENTATION_HEADER_RESPONSE_CODE_INDEX = 17;
  final int PRESENTATION_HEADER_TRANSACTION_CODE_INDEX = 15;
  final int FIELD_DATA_INDEX = 21;

  Uint8List? byteData;

  String? transactionDate;
  String? transactionTime;

  /// Presentation Response Code
  String? responseCode;

  /// Presentation Transaction Code
  String? transactionCode;

  /// Field Type : 01
  String? approvalCode;

  /// Field Type : 02
  String? responseText;

  /// Field Type : D0
  String? merchantName;

  /// Field Type : D2
  String? cardIssuerName;

  /// Field Type : 30
  String? cardNumber;

  /// Field Type : D5
  String? cardHolderName;

  /// Field Type : 31
  String? cardExpire;

  /// Field Type : 50
  String? batchNumber;

  /// Field Type : 40 , Amount With Satang 00
  Decimal? amount;

  /// Field Type : R1
  String? ref1;

  /// Field Type : R2
  String? ref2;

  /// Field Type : 65, Terminal Invoice Number
  String? terminalInvoiceNumber;

  /// Field Type : 16, TID, Terminal Identification Number
  String? terminalIdentificationNumber;

  String? retriveReferenceNumber;

  bool isMessageStartOfText() {
    if (byteData != null && byteData![0] == 0x02) return true;
    return false;
  }

  void loadResponseBytes(List<int> bytes) {
    byteData = Uint8List.fromList(bytes);
    processData();
  }

  static int calcHexBCDtoTextSize(List<int> fieldElementBytes) {
    if (fieldElementBytes.length != 2) {
      return -1;
    }

    String firstDigit = fieldElementBytes[0].toRadixString(16).padLeft(2, '0');
    String secondDigit = fieldElementBytes[1].toRadixString(16).padLeft(2, '0');

    int firstSize = int.parse(firstDigit) * 100;
    int secondSize = int.parse(secondDigit);
    int result = firstSize + secondSize;
    return result;
  }

  void processData() {
    if (isMessageStartOfText()) {
      responseCode = _getResponseCode();
      transactionCode = _getTransactionCode();

      List<int>? fieldDatas = _getFieldDataBytes();
      if (fieldDatas != null) {
        int index = 0;
        while (index < fieldDatas.length) {
          bool isFieldOverLength = index + 2 > fieldDatas.length;

          if (isFieldOverLength == false) {
            // copy next 2 bytes
            List<int> fieldDataLengthBytes = fieldDatas.getRange(index + 2, index + 4).toList();
            int dataLength = EDCResponse.calcHexBCDtoTextSize(fieldDataLengthBytes);
            dataLength += 4;

            List<int> fieldElementBytes = fieldDatas.getRange(index, index + dataLength).toList();

            _extractFieldData(fieldElementBytes);
            index += (dataLength + 1);
          } else {
            index = fieldDatas.length;
          }
        }
      }
    }
  }

  void _extractFieldData(List<int> bytes) {
    EDCFieldElement element = EDCFieldElement();
    element.loadData(bytes);

    print('${element.fieldType} : ${element.data}');

    switch (element.fieldType) {
      case "01":
        // Approval Code
        approvalCode = element.data;
        break;
      case "02":
        // response text
        responseText = element.data?.trim();
        break;
      case "03":
        transactionDate = element.data;
        break;
      case "04":
        transactionTime = element.data;
        break;
      case "16":
        terminalIdentificationNumber = element.data;
        break;
      case "30":
        cardNumber = element.data;
        break;
      case "31":
        cardExpire = element.data;
        break;
      case "40":
        if (element.data != null) {
          amount = Decimal.parse(element.data!) * Decimal.parse('0.01');
        }
        break;
      case "50":
        batchNumber = element.data;
        break;
      case "65":
        terminalInvoiceNumber = element.data;
        break;
      case "D0":
        merchantName = element.data?.trim();
        break;
      case "D2":
        cardIssuerName = element.data?.trim();
        break;
      case "D3":
        retriveReferenceNumber = element.data;
        break;
      case "D5":
        cardHolderName = element.data?.trim();
        break;
      case "R1":
        ref1 = element.data?.trim();
        break;
      case "R2":
        ref2 = element.data?.trim();
        break;
    }
  }

  String _getResponseCode() {
    if (byteData != null) {
      List<int> targetBlock = byteData!.getRange(PRESENTATION_HEADER_RESPONSE_CODE_INDEX, PRESENTATION_HEADER_RESPONSE_CODE_INDEX + 2).toList();

      String result = _getStringFromBytes(targetBlock);
      return result;
    }
    return "";
  }

  String _getTransactionCode() {
    if (byteData != null) {
      List<int> targetBlock = byteData!.getRange(PRESENTATION_HEADER_TRANSACTION_CODE_INDEX, PRESENTATION_HEADER_TRANSACTION_CODE_INDEX + 2).toList();

      String result = _getStringFromBytes(targetBlock);
      return result;
    }
    return "";
  }

  String _getStringFromBytes(List<int> bytes) {
    String data = const Utf8Decoder().convert(bytes);
    return data;
  }

  List<int>? _getFieldDataBytes() {
    if (byteData != null) {
      List<int> targetBlock = byteData!.getRange(FIELD_DATA_INDEX, byteData!.length - 1).toList();
      return targetBlock;
    }
    return null;
  }

  /// Is Accept Data Response

  bool isMessageSuccessACK() {
    if (byteData != null && byteData![0] == 0x06) return true;
    return false;
  }

  bool isDuplicateSend() {
    if (byteData != null && byteData![0] == 21) return true;
    return false;
  }

  bool isResponseSuccess() {
    if (responseCode != null && responseCode == "00") return true;
    return false;
  }

  bool isResponseCancel() {
    if (responseCode != null && responseCode == "ND") return true;
    return false;
  }
}
