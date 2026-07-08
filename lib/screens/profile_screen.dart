import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/session_provider.dart';
import '../providers/favorito_provider.dart';
import '../providers/visita_provider.dart';
import '../models/destino_model.dart';
import '../widgets/destino_card_editable.dart';
import '../screens/add_destino_screen.dart';
import '../services/visita_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isEditing = false;
  final TextEditingController nombreController = TextEditingController();
  
  // Variables para la sección de destinos
  List<Destino> _misDestinos = [];
  bool _cargandoDestinos = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    if (session.user != null) {
      nombreController.text = session.user!.nombre;
    }
    _cargarMisDestinos();
  }

  @override
  void dispose() {
    nombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarMisDestinos() async {
    setState(() => _cargandoDestinos = true);
    
    try {
      final session = context.read<SessionProvider>();
      final supabase = Supabase.instance.client;
      final visitaService = VisitaService();
      
      if (session.user == null) return;

      // Obtener destinos del usuario
      final response = await supabase
          .from('destinos')
          .select()
          .eq('uid', session.user!.uid)
          .order('created_at', ascending: false);

      List<Destino> destinos = response.map((map) => Destino.fromMap(map)).toList();

      // Cargar calificaciones para cada destino
      if (destinos.isNotEmpty) {
        final destinoIds = destinos.map((d) => d.id).toList();
        final calificaciones = await visitaService.getCalificacionesForDestinos(destinoIds);
        
        destinos = destinos.map((destino) {
          final data = calificaciones[destino.id];
          if (data != null) {
            return destino.copyWith(
              promedioCalificacion: data['promedio'],
              totalCalificaciones: data['total'],
            );
          }
          return destino;
        }).toList();
      }

      setState(() {
        _misDestinos = destinos;
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar destinos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoDestinos = false);
    }
  }

  Future<void> _eliminarDestino(String destinoId) async {
    try {
      final supabase = Supabase.instance.client;
      final session = context.read<SessionProvider>();
      
      await supabase
          .from('destinos')
          .delete()
          .eq('id', destinoId)
          .eq('uid', session.user!.uid);
      
      // Remover de la lista local
      setState(() {
        _misDestinos.removeWhere((d) => d.id == destinoId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Destino eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final user = session.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepOrange.shade500,
                  Colors.deepOrange.shade300,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: Text(
                    user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 18),
              if (!isEditing) ...[
                Text(
                  user.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'ID: ${user.uid.substring(0, 8)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isEditing = true;
                      nombreController.text = user.nombre;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar nombre'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (nombreController.text.trim().isNotEmpty) {
                            try {
                              await session.updateProfile(nombreController.text.trim());
                              setState(() {
                                isEditing = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nombre actualizado')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: BorderSide(color: Colors.deepOrange.shade200),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          setState(() {
                            isEditing = false;
                            nombreController.text = user.nombre;
                          });
                        },
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Cerrar sesión'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    context.read<FavoritoProvider>().clearFavoritos();
                    await context.read<SessionProvider>().logout();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const Divider(thickness: 2, height: 28),
          
          // Sección "Mis Destinos"
          Row(
            children: [
              const Text(
                'Mis Destinos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.deepOrange,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddDestinoScreen(),
                    ),
                  );
                  if (result == true) {
                    _cargarMisDestinos();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _cargarMisDestinos,
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Lista de destinos del usuario
          if (_cargandoDestinos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_misDestinos.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.travel_explore,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No has agregado destinos aún',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Usa el botón + para crear tu primer destino.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _misDestinos.length,
              itemBuilder: (context, index) {
                final destino = _misDestinos[index];
                return DestinoCardEditable(
                  destino: destino,
                  onDelete: () => _eliminarDestino(destino.id),
                  onUpdate: _cargarMisDestinos,
                );
              },
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}