import 'package:flutter/material.dart';
import '../services/sintoma_service.dart';

class SintomaScreen extends StatefulWidget {

  final int idUsuario;

  SintomaScreen({required this.idUsuario});

  @override
  State<SintomaScreen> createState() => _SintomaScreenState();
}

class _SintomaScreenState extends State<SintomaScreen> {

  final service = SintomaService();

  List sintomas = [];

  TextEditingController titulo = TextEditingController();
  TextEditingController descripcion = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargar();
  }

  void cargar() async {
    sintomas = await service.getSintomasByUser(widget.idUsuario);
    setState(() {});
  }

  void guardarSintoma() async {

    await service.crearSintoma(
      idUsuario: widget.idUsuario,
      titulo: titulo.text,
      descripcion: descripcion.text,
      prioridad: "MEDIA",
    );

    titulo.clear();
    descripcion.clear();

    cargar();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: Text("Síntomas 🧠")),

      body: Column(

        children: [

          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [

                TextField(
                  controller: titulo,
                  decoration: InputDecoration(
                    labelText: "Título",
                  ),
                ),

                TextField(
                  controller: descripcion,
                  decoration: InputDecoration(
                    labelText: "Descripción",
                  ),
                ),

                SizedBox(height: 10),

                ElevatedButton(
                  onPressed: guardarSintoma,
                  child: Text("Registrar síntoma"),
                ),
              ],
            ),
          ),

          Divider(),

          Expanded(
            child: ListView(

              children: sintomas.map((s) => Card(
                child: ListTile(
                  title: Text(s['titulo']),
                  subtitle: Text(s['descripcion']),
                ),
              )).toList(),

            ),
          ),
        ],
      ),
    );
  }
}