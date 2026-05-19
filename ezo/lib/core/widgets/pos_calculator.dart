import 'package:flutter/material.dart';

class PosCalculator extends StatefulWidget {
  final VoidCallback? onClose;

  const PosCalculator({super.key, this.onClose});

  @override
  State<PosCalculator> createState() => _PosCalculatorState();
}

class _PosCalculatorState extends State<PosCalculator> {
  String _displayText = '0';
  double? _firstOperand;
  String? _operator;
  bool _isNewNumber = true;

  void _onNumberPressed(String number) {
    setState(() {
      if (_isNewNumber) {
        _displayText = number;
        _isNewNumber = false;
      } else {
        // Prevent multiple decimals
        if (number == '.' && _displayText.contains('.')) return;
        
        // Remove leading zero unless it's a decimal
        if (_displayText == '0' && number != '.') {
          _displayText = number;
        } else {
          _displayText += number;
        }
      }
    });
  }

  void _onOperatorPressed(String operator) {
    setState(() {
      if (_firstOperand == null) {
        _firstOperand = double.tryParse(_displayText);
      } else if (!_isNewNumber) {
        _calculate();
      }
      _operator = operator;
      _isNewNumber = true;
    });
  }

  void _calculate() {
    if (_firstOperand == null || _operator == null) return;
    
    final secondOperand = double.tryParse(_displayText) ?? 0.0;
    double result = 0.0;

    switch (_operator) {
      case '+':
        result = _firstOperand! + secondOperand;
        break;
      case '-':
        result = _firstOperand! - secondOperand;
        break;
      case '×':
        result = _firstOperand! * secondOperand;
        break;
      case '÷':
        if (secondOperand != 0) {
          result = _firstOperand! / secondOperand;
        } else {
          _displayText = 'Error';
          _firstOperand = null;
          _operator = null;
          _isNewNumber = true;
          return;
        }
        break;
    }

    _displayText = _formatResult(result);
    _firstOperand = result;
    _operator = null;
    _isNewNumber = true;
  }

  String _formatResult(double result) {
    if (result == result.truncateToDouble()) {
      return result.truncate().toString();
    }
    // Limit to 4 decimal places to prevent display overflow
    String res = result.toStringAsFixed(4);
    // Remove trailing zeros
    return res.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void _onClearPressed() {
    setState(() {
      _displayText = '0';
      _firstOperand = null;
      _operator = null;
      _isNewNumber = true;
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (_isNewNumber) return;
      
      if (_displayText.length > 1) {
        _displayText = _displayText.substring(0, _displayText.length - 1);
      } else {
        _displayText = '0';
        _isNewNumber = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Calculator',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                  ),
              ],
            ),
          ),
          
          // Display
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_operator != null && _firstOperand != null)
                  Text(
                    '${_formatResult(_firstOperand!)} $_operator',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  )
                else
                  const SizedBox(height: 16), // Placeholder to maintain height
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    _displayText,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: Colors.grey.shade200),
          
          // Keypad
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildButton('C', color: Colors.red.shade400, onTap: _onClearPressed),
                    const SizedBox(width: 8),
                    _buildButton('⌫', color: Colors.orange.shade400, onTap: _onDeletePressed),
                    const SizedBox(width: 8),
                    _buildButton('÷', color: const Color(0xFF007AFF), onTap: () => _onOperatorPressed('÷')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildButton('7', onTap: () => _onNumberPressed('7')),
                    const SizedBox(width: 8),
                    _buildButton('8', onTap: () => _onNumberPressed('8')),
                    const SizedBox(width: 8),
                    _buildButton('9', onTap: () => _onNumberPressed('9')),
                    const SizedBox(width: 8),
                    _buildButton('×', color: const Color(0xFF007AFF), onTap: () => _onOperatorPressed('×')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildButton('4', onTap: () => _onNumberPressed('4')),
                    const SizedBox(width: 8),
                    _buildButton('5', onTap: () => _onNumberPressed('5')),
                    const SizedBox(width: 8),
                    _buildButton('6', onTap: () => _onNumberPressed('6')),
                    const SizedBox(width: 8),
                    _buildButton('-', color: const Color(0xFF007AFF), onTap: () => _onOperatorPressed('-')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildButton('1', onTap: () => _onNumberPressed('1')),
                    const SizedBox(width: 8),
                    _buildButton('2', onTap: () => _onNumberPressed('2')),
                    const SizedBox(width: 8),
                    _buildButton('3', onTap: () => _onNumberPressed('3')),
                    const SizedBox(width: 8),
                    _buildButton('+', color: const Color(0xFF007AFF), onTap: () => _onOperatorPressed('+')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildButton('0', flex: 2, onTap: () => _onNumberPressed('0')),
                    const SizedBox(width: 8),
                    _buildButton('.', onTap: () => _onNumberPressed('.')),
                    const SizedBox(width: 8),
                    _buildButton('=', color: const Color(0xFF16A34A), onTap: _calculate),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    String label, {
    Color? color,
    int flex = 1,
    required VoidCallback onTap,
  }) {
    final isNumberOrDot = int.tryParse(label) != null || label == '.';
    final bgColor = color ?? (isNumberOrDot ? Colors.grey.shade100 : Colors.grey.shade200);
    final textColor = color != null ? Colors.white : const Color(0xFF0F172A);

    return Expanded(
      flex: flex,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 22,
                fontWeight: isNumberOrDot ? FontWeight.w500 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
