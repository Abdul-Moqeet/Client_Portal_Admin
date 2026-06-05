import 'package:client_portal_admin/widget_admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
    await Supabase.initialize(
    url: 'https://dyylnxkegoumezooqkaj.supabase.co',
    anonKey: 'sb_publishable_UbdD-Va_neXP7idDGp9ILA_gB1X7Dhf',
  );


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
      Supabase.instance.client.auth.signInWithPassword(
    email: 'araranonymous9@gmail.com',
    password: 'password'
  );
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

@override
  void initState() {
    super.initState();
    _loadWidgetsFromSupabase();
  }

bool _isLoading = false;
List<Map<String, dynamic>> _widgetData = [];


String get userId => Supabase.instance.client.auth.currentUser?.id ?? '';

 Future<void> _loadWidgetsFromSupabase() async {
  setState(() => _isLoading = true);
  try {
    final organisationId = await Supabase.instance.client
        .from('users')
        .select('organisation_id')
        .eq('id', userId)
        .single();

    final response = await Supabase.instance.client
        .from('widgets_data')
        .select()
        .eq('organisation_id', organisationId['organisation_id'])
        .order('position', ascending: true);

    // response is already List<Map<String, dynamic>> — pass it straight in
    setState(() {
      print('response: $response');
      _widgetData = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    debugPrint('Error loading widgets: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(

       
        title: Text(widget.title),
      ),
      body: Center(
        child:
        TextButton(
          onPressed: () {Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WidgetAdminScreen(initialWidgets: _widgetData)),
          );},
          child: const Text('Load Widgets'),
        ),
       
      ),
 
    );
  }
}
