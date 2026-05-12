enum PowerUpRarity { common, uncommon, rare, ultraRare }

enum PowerUpType { berry, bloom, pollen, water, firefly }

extension PowerUpTypeDetails on PowerUpType {
  String get label {
    return switch (this) {
      PowerUpType.berry => 'Berry',
      PowerUpType.bloom => 'Bloom',
      PowerUpType.pollen => 'Pollen',
      PowerUpType.water => 'Water Drop',
      PowerUpType.firefly => 'Firefly',
    };
  }

  PowerUpRarity get rarity {
    return switch (this) {
      PowerUpType.berry || PowerUpType.bloom => PowerUpRarity.common,
      PowerUpType.pollen => PowerUpRarity.uncommon,
      PowerUpType.water => PowerUpRarity.rare,
      PowerUpType.firefly => PowerUpRarity.ultraRare,
    };
  }

  String get iconAsset {
    return switch (this) {
      PowerUpType.berry => 'assets/images/power_btns/power_icon_berry.png',
      PowerUpType.bloom => 'assets/images/power_btns/power_icon_bloom.png',
      PowerUpType.pollen => 'assets/images/power_btns/power_icon_pollen.png',
      PowerUpType.water => 'assets/images/power_btns/power_icon_water.png',
      PowerUpType.firefly => 'assets/images/power_btns/power_icon_firefly.png',
    };
  }

  String get frameAsset {
    return switch (rarity) {
      PowerUpRarity.common => 'assets/images/power_btns/power_btn_common.png',
      PowerUpRarity.uncommon =>
        'assets/images/power_btns/power_btn_uncommon.png',
      PowerUpRarity.rare => 'assets/images/power_btns/power_btn_Rare.png',
      PowerUpRarity.ultraRare =>
        'assets/images/power_btns/power_btn_ultraRare.png',
    };
  }

  String get pressedFrameAsset {
    return switch (rarity) {
      PowerUpRarity.common =>
        'assets/images/power_btns/power_btn_common_pressed.png',
      PowerUpRarity.uncommon =>
        'assets/images/power_btns/power_btn_uncommon_pressed.png',
      PowerUpRarity.rare =>
        'assets/images/power_btns/power_btn_Rare_pressed.png',
      PowerUpRarity.ultraRare =>
        'assets/images/power_btns/power_btn_ultraRare_pressed.png',
    };
  }
}

class PowerUpSlotState {
  const PowerUpSlotState({
    required this.type,
    required this.count,
    required this.locked,
    required this.selected,
  });

  final PowerUpType? type;
  final int count;
  final bool locked;
  final bool selected;

  bool get enabled => !locked && type != null && count > 0;
}
