import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final Color color;

  const Category({
    required this.id,
    required this.name,
    required this.color,
  });

  static const List<Category> defaultCategories = [
    Category(
      id: 'work',
      name: 'Trabalho',
      color: Color(0xFF2196F3), // Azul
    ),
    Category(
      id: 'personal',
      name: 'Pessoal',
      color: Color(0xFF4CAF50), // Verde
    ),
    Category(
      id: 'study',
      name: 'Estudos',
      color: Color(0xFFFF9800), // Laranja
    ),
    Category(
      id: 'health',
      name: 'Saúde',
      color: Color(0xFFE91E63), // Rosa
    ),
    Category(
      id: 'shopping',
      name: 'Compras',
      color: Color(0xFF9C27B0), // Roxo
    ),
    Category(
      id: 'other',
      name: 'Outros',
      color: Color(0xFF607D8B), // Cinza azulado
    ),
  ];

  static Category? getById(String? id) {
    if (id == null) return null;
    try {
      return defaultCategories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return defaultCategories.last; // Retorna "Outros" se não encontrar
    }
  }
}

