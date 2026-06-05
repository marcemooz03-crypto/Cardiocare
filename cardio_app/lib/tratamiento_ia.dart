class TratamientoIA {

  static List<Map<String, dynamic>> sugerir(String prioridad) {

    if (prioridad.toLowerCase() == "alta") {

      return [
        {
          "idMedicamento": 1, // Losartán
          "dosis": "50mg",
          "frecuencia": "1 vez al día"
        },
        {
          "idMedicamento": 3, // Amlodipino
          "dosis": "5mg",
          "frecuencia": "1 vez al día"
        }
      ];
    }

    if (prioridad.toLowerCase() == "media") {

      return [
        {
          "idMedicamento": 1,
          "dosis": "50mg",
          "frecuencia": "1 vez al día"
        }
      ];
    }

    return [
      {
        "idMedicamento": 4, // Hidroclorotiazida
        "dosis": "25mg",
        "frecuencia": "1 vez al día"
      }
    ];
  }
}