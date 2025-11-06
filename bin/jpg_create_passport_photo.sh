#!/bin/bash
set -e

# --- Controllo parametri ---
if [ $# -ne 7 ]
then
  echo "Usage: $0 <input.jpg> <Y_top_px> <Y_chin_px> <Y_eyes_px> <X_nose_px> <output_collage.jpg> <output_single.jpg>"
  exit 1
fi

INPUT="$1"
Y_TOP="$2"
Y_CHIN="$3"
Y_EYES="$4"
X_NOSE="$5"
OUT_FINAL="$6"
OUT_SINGLE="$7"
DPI=600

# --- Controllo esistenza file ---
if [ ! -f "$INPUT" ]; then
  echo "Error: file '$INPUT' not found! Stopped."
  exit 1
fi

# --- Conversione mm -> px ---
MM_TO_PX() {
  echo "$(printf "%.0f" "$(echo "$1 * $DPI / 25.4" | bc -l)")"
}

PHOTO_W=$(MM_TO_PX 35)
PHOTO_H=$(MM_TO_PX 45)
TARGET_FACE_HEIGHT=$(MM_TO_PX 30)

# --- Dimensioni immagine sorgente ---
read IMG_W IMG_H <<<$(identify -format "%w %h" "$INPUT")

# --- Calcolo fattore di scala per avere 30 mm tra mento e testa ---
FACE_HEIGHT_SRC=$((Y_CHIN - Y_TOP))
SCALE=$(echo "$TARGET_FACE_HEIGHT / $FACE_HEIGHT_SRC" | bc -l)

RESIZED_W=$(printf "%.0f" "$(echo "$IMG_W * $SCALE" | bc -l)")
RESIZED_H=$(printf "%.0f" "$(echo "$IMG_H * $SCALE" | bc -l)")

# --- Ridimensionamento ---
TMP_RESIZED="/tmp/foto_resized_$$.jpg"
magick "$INPUT" -resize "${RESIZED_W}x${RESIZED_H}" "$TMP_RESIZED"

# --- Ricalcolo coordinate dopo ridimensionamento ---
Y_EYES_SCALED=$(printf "%.0f" "$(echo "$Y_EYES * $SCALE" | bc -l)")
X_NOSE_SCALED=$(printf "%.0f" "$(echo "$X_NOSE * $SCALE" | bc -l)")

# --- Calcolo verticale: occhi a 27 mm dal fondo (tra 23 e 31 mm standard) ---
EYES_TARGET_FROM_BOTTOM=$(MM_TO_PX 27)
CROP_Y_START=$(printf "%.0f" "$(echo "$Y_EYES_SCALED - ($PHOTO_H - $EYES_TARGET_FROM_BOTTOM)" | bc -l)")

# Limiti verticali
if [ "$CROP_Y_START" -lt 0 ]; then
  CROP_Y_START=0
fi
if [ "$(echo "$CROP_Y_START + $PHOTO_H > $RESIZED_H" | bc)" -eq 1 ]; then
  CROP_Y_START=$(printf "%.0f" "$(echo "$RESIZED_H - $PHOTO_H" | bc -l)")
fi

# --- Calcolo orizzontale: centrato sul naso ---
CROP_X_START=$(printf "%.0f" "$(echo "$X_NOSE_SCALED - ($PHOTO_W / 2)" | bc -l)")

# Limiti orizzontali
if [ "$CROP_X_START" -lt 0 ]; then
  CROP_X_START=0
fi
if [ "$(echo "$CROP_X_START + $PHOTO_W > $RESIZED_W" | bc)" -eq 1 ]; then
  CROP_X_START=$(printf "%.0f" "$(echo "$RESIZED_W - $PHOTO_W" | bc -l)")
fi

# --- Taglio della singola fototessera ---
magick "$TMP_RESIZED" -crop ${PHOTO_W}x${PHOTO_H}+$CROP_X_START+$CROP_Y_START +repage "$OUT_SINGLE"

echo "✅ Fototessera singola creata: $OUT_SINGLE"

# --- Creazione collage 10x15 cm (verticale) ---
CANVAS_W=$(MM_TO_PX 100)
CANVAS_H=$(MM_TO_PX 150)

# vecchio comando: convert -size ${CANVAS_W}x${CANVAS_H} xc:white "$OUT_FINAL"
# magick -size ${CANVAS_W}x${CANVAS_H} canvas:white -colorspace sRGB "$OUT_FINAL"
magick -size ${CANVAS_W}x${CANVAS_H} xc:white -depth 8 -type TrueColor -colorspace sRGB "$OUT_FINAL"

# Margini (float → int)
MARGIN_X_FLOAT=$(echo "($CANVAS_W - 2 * $PHOTO_W) / 3" | bc -l)
MARGIN_Y_FLOAT=$(echo "($CANVAS_H - 2 * $PHOTO_H) / 3" | bc -l)
MARGIN_X=$(printf "%.0f" "$MARGIN_X_FLOAT")
MARGIN_Y=$(printf "%.0f" "$MARGIN_Y_FLOAT")

# Posizioni
X1=$MARGIN_X
Y1=$MARGIN_Y
X2=$(printf "%.0f" "$(echo "2*$MARGIN_X + $PHOTO_W" | bc -l)")
Y2=$Y1
X3=$X1
Y3=$(printf "%.0f" "$(echo "2*$MARGIN_Y + $PHOTO_H" | bc -l)")
X4=$X2
Y4=$Y3

# Composizione finale
magick "$OUT_FINAL" \
  \( "$OUT_SINGLE" \) -geometry +$X1+$Y1 -composite \
  \( "$OUT_SINGLE" \) -geometry +$X2+$Y2 -composite \
  \( "$OUT_SINGLE" \) -geometry +$X3+$Y3 -composite \
  \( "$OUT_SINGLE" \) -geometry +$X4+$Y4 -composite \
  -colorspace sRGB -depth 8 \
  "$OUT_FINAL"

rm -f "$TMP_RESIZED"

echo "✅ Collage 10x15 cm creato: $OUT_FINAL"
echo "📏 Volto 30 mm, occhi a 27 mm dal fondo, centrato sul naso, 600 DPI."
exit 0
