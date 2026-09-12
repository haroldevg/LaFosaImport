import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../services/listing_scraper_service.dart';

final _currency = NumberFormat.simpleCurrency(name: 'USD');

const _conditions = [
  'Near Mint',
  'Lightly Played',
  'Moderately Played',
  'Heavily Played',
  'Damaged',
];

/// Adds a single [OrderItem] to the cart being built in [NewOrderScreen].
/// Pasting a TCGPlayer link (and picking a seller found by
/// [ListingScraperService]) is the primary path, chosen up front via the
/// segmented toggle. In that mode the card name/set/condition fields are
/// locked (they should come from the scrape, not be typed ahead of it) and
/// only unlock individually if the scrape couldn't fill them; quantity is
/// capped at the seller's stock. Manual entry is the fallback and — per
/// design — never asks for a specific seller or caps quantity, just a rough
/// reference price the staff will match when buying for real.
class AddCardItemScreen extends StatefulWidget {
  const AddCardItemScreen({super.key});

  @override
  State<AddCardItemScreen> createState() => _AddCardItemScreenState();
}

class _AddCardItemScreenState extends State<AddCardItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNameCtrl = TextEditingController();
  final _setNameCtrl = TextEditingController();
  final _listingUrlCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _condition = _conditions.first;
  bool _useLink = true;
  bool _searchingListings = false;
  String? _pickedSeller;
  double _pickedUnitPrice = 0;
  double _pickedShipping = 0;
  int? _maxQuantity;
  int _quantity = 1;
  String? _error;

  // While in link mode, these fields are locked until a search fills them —
  // and stay locked afterward unless the scrape came back empty for that
  // field, in which case it unlocks so the user can complete it by hand.
  bool _cardNameLocked = true;
  bool _setNameLocked = true;
  bool _conditionLocked = true;

  @override
  void dispose() {
    _cardNameCtrl.dispose();
    _setNameCtrl.dispose();
    _listingUrlCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _setMode(bool useLink) {
    setState(() {
      _useLink = useLink;
      _error = null;
      _quantity = 1;
      if (useLink) {
        // Fields go back to locked until the next search resolves them.
        _cardNameLocked = true;
        _setNameLocked = true;
        _conditionLocked = true;
        _maxQuantity = null;
        _pickedSeller = null;
      } else {
        _cardNameLocked = false;
        _setNameLocked = false;
        _conditionLocked = false;
        _maxQuantity = null;
      }
    });
  }

  void _resetPickedSeller() {
    _pickedSeller = null;
    _maxQuantity = null;
    _quantity = 1;
    _cardNameLocked = true;
    _setNameLocked = true;
    _conditionLocked = true;
  }

  Future<void> _searchListings() async {
    final url = _listingUrlCtrl.text.trim();
    if (!ListingScraperService.instance.looksLikeTcgplayerUrl(url)) {
      setState(
        () => _error =
            'Pega primero un link válido de un producto de tcgplayer.com.',
      );
      return;
    }
    setState(() {
      _searchingListings = true;
      _error = null;
    });
    final result = await ListingScraperService.instance.fetchListings(
      context,
      url,
    );
    if (!mounted) return;
    setState(() => _searchingListings = false);

    if (result.listings.isEmpty) {
      setState(
        () => _error =
            'No se pudieron obtener vendedores automáticamente. Verifica el link o intenta de nuevo.',
      );
      return;
    }

    setState(() {
      _cardNameCtrl.text = result.cardName;
      _cardNameLocked = result.cardName.isNotEmpty;
      _setNameCtrl.text = result.setName;
      _setNameLocked = result.setName.isNotEmpty;
    });

    final picked = await showModalBottomSheet<ScrapedListing>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Vendedores encontrados',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final listing in result.listings)
              ListTile(
                title: Text(listing.sellerName),
                subtitle: Text(
                  [
                    listing.condition,
                    if (listing.stock != null) 'Stock: ${listing.stock}',
                  ].join(' · '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_currency.format(listing.itemPrice)),
                    Text(
                      listing.shipping > 0
                          ? '+ ${_currency.format(listing.shipping)} envío'
                          : 'Envío incluido',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () => Navigator.of(context).pop(listing),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    setState(() {
      _pickedSeller = picked.sellerName;
      _pickedUnitPrice = picked.itemPrice;
      _pickedShipping = picked.shipping;
      _maxQuantity = picked.stock;
      _quantity = 1;
      final match = _conditions.firstWhere(
        (c) => picked.condition.toLowerCase().contains(c.toLowerCase()),
        orElse: () => '',
      );
      _conditionLocked = match.isNotEmpty;
      _condition = match.isNotEmpty ? match : _condition;
      _error = null;
    });
  }

  void _addToCart() {
    if (_error != null) setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    if (_useLink && _pickedSeller == null) {
      setState(
        () => _error =
            'Busca y selecciona un vendedor primero (o cambia a "Manual").',
      );
      return;
    }

    final unitPrice = _useLink
        ? _pickedUnitPrice
        : double.parse(_priceCtrl.text.trim());
    Navigator.of(context).pop(
      OrderItem(
        cardName: _cardNameCtrl.text.trim(),
        setName: _setNameCtrl.text.trim(),
        condition: _condition,
        unitPrice: unitPrice,
        shipping: _useLink ? _pickedShipping : 0,
        quantity: _quantity,
        sellerName: _useLink ? _pickedSeller : null,
        listingUrl: _useLink ? _listingUrlCtrl.text.trim() : null,
        isReferencePrice: !_useLink,
      ),
    );
  }

  Widget _buildQuantityStepper() {
    final atMax = _maxQuantity != null && _quantity >= _maxQuantity!;
    return Row(
      children: [
        const Text('Cantidad'),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
        ),
        Text('$_quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: atMax ? null : () => setState(() => _quantity++),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar carta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Con link de TCGPlayer'),
                  ),
                  ButtonSegment(value: false, label: Text('Manual')),
                ],
                selected: {_useLink},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
              const SizedBox(height: 16),
              if (_useLink) ...[
                TextFormField(
                  controller: _listingUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Link del listado en TCGPlayer',
                    hintText: 'https://www.tcgplayer.com/product/...',
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(_resetPickedSeller),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _searchingListings ? null : _searchListings,
                    icon: _searchingListings
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                      _searchingListings ? 'Buscando…' : 'Buscar vendedores',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_pickedSeller != null)
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      title: Text(_pickedSeller!),
                      subtitle: Text(
                        'Precio: ${_currency.format(_pickedUnitPrice)}'
                        '${_pickedShipping > 0 ? ' + ${_currency.format(_pickedShipping)} envío' : ' (envío incluido)'}'
                        '${_maxQuantity != null ? ' · Stock: $_maxQuantity' : ''}',
                      ),
                      trailing: const Icon(Icons.check_circle),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _cardNameCtrl,
                enabled: !_cardNameLocked,
                decoration: InputDecoration(
                  labelText: 'Nombre de la carta',
                  helperText: _cardNameLocked
                      ? 'Se completa al buscar el link'
                      : null,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _setNameCtrl,
                enabled: !_setNameLocked,
                decoration: InputDecoration(
                  labelText: 'Set / expansión',
                  helperText: _setNameLocked
                      ? 'Se completa al buscar el link'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: InputDecoration(
                  labelText: 'Condición',
                  helperText: _conditionLocked
                      ? 'Se completa al elegir un vendedor'
                      : null,
                ),
                items: _conditions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: _conditionLocked
                    ? null
                    : (v) => setState(() => _condition = v!),
              ),
              if (!_useLink) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio referencial (USD)',
                    prefixText: '\$ ',
                    helperText:
                        'Estimado — el staff confirma el vendedor y precio exactos al comprar.',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) return 'Precio inválido';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              _buildQuantityStepper(),
              if (_useLink && _maxQuantity != null)
                Text(
                  'Máximo disponible con este vendedor: $_maxQuantity',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Agregar a mi pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
