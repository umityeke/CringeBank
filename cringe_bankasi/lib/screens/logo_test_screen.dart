import 'package:flutter/material.dart';
import '../widgets/cringe_logos.dart';

class LogoTestScreen extends StatefulWidget {
  const LogoTestScreen({super.key});
  
  @override
  State<LogoTestScreen> createState() => _LogoTestScreenState();
}

class _LogoTestScreenState extends State<LogoTestScreen> {
  bool _animate = true;
  double _size = 150.0;
  LogoType _selectedType = LogoType.classic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Logo Test Alanı',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Ana Logo Display
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: CringeBankLogo(
                  type: _selectedType,
                  size: _size,
                  animate: _animate,
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            // Kontroller
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontroller',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    
                    // Logo Tipi Seçimi
                    Text('Logo Tipi:', style: TextStyle(fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: LogoType.values.map((type) {
                        final names = {
                          LogoType.classic: 'Klasik',
                          LogoType.safe: 'Kasa',
                          LogoType.modern: 'Modern',
                          LogoType.piggy: 'Kumbara',
                          LogoType.galaxy: 'Galaksi',
                        };
                        
                        return ChoiceChip(
                          label: Text(names[type]!),
                          selected: _selectedType == type,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = type;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Animasyon Toggle
                    Row(
                      children: [
                        Text('Animasyon:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Spacer(),
                        Switch(
                          value: _animate,
                          onChanged: (value) {
                            setState(() {
                              _animate = value;
                            });
                          },
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 15),
                    
                    // Boyut Slider
                    Text('Boyut: ${_size.toInt()}px', style: TextStyle(fontWeight: FontWeight.w500)),
                    Slider(
                      value: _size,
                      min: 50,
                      max: 300,
                      divisions: 25,
                      label: _size.toInt().toString(),
                      onChanged: (value) {
                        setState(() {
                          _size = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Hızlı Örnekler
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hızlı Örnekler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    
                    Row(
                      children: [
                        _buildQuickExample('App Bar', LogoType.modern, 30, false),
                        SizedBox(width: 15),
                        _buildQuickExample('Avatar', LogoType.classic, 40, false),
                        SizedBox(width: 15),
                        _buildQuickExample('Hero', LogoType.galaxy, 100, true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Kod Örneği
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kod Örneği',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'CringeBankLogo(\n'
                        '  type: LogoType.${_selectedType.toString().split('.').last},\n'
                        '  size: ${_size.toInt()},\n'
                        '  animate: $_animate,\n'
                        ')',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickExample(String label, LogoType type, double size, bool animate) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _size = size;
            _animate = animate;
          });
        },
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedType == type ? Colors.purple : Colors.grey.shade300,
              width: _selectedType == type ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              CringeBankLogo(
                type: type,
                size: size,
                animate: animate,
              ),
              SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
