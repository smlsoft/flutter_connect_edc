import 'edc_response.dart';
import 'dart:convert';

class EDCFieldElement {
  String? fieldType;
  int? length;
  String? data;

  EDCFieldElement();

  void loadData(List<int> fieldElementBytes) {
    // byte 0-1 is fieldtype
    List<int> fieldTypeBytes = fieldElementBytes.getRange(0, 2).toList();
    // Array.Copy(fieldElementBytes, 0, fieldTypeBytes, 0, 2);

    // byte 3-4 is fieldtype
    // byte[] fieldLengthBytes = new byte[2];
    // Array.Copy(fieldElementBytes, 2, fieldLengthBytes, 0, 2);
    List<int> fieldLengthBytes = fieldElementBytes.getRange(2, 4).toList();
    int dataLength = EDCResponse.calcHexBCDtoTextSize(fieldLengthBytes);

    // byte[] fieldDataBytes = new byte[dataLength];
    // Array.Copy(fieldElementBytes, 4, fieldDataBytes, 0, dataLength);
    List<int> fieldDataBytes =
        fieldElementBytes.getRange(4, 4 + dataLength).toList();

    fieldType = const Utf8Decoder().convert(fieldTypeBytes);
    data = const Utf8Decoder().convert(fieldDataBytes);
  }
}
