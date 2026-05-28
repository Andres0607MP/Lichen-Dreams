import cv2

# Cambia la ruta según la imagen que agregues
imagen = cv2.imread("datasets/liquenes_saludables/liquen_001.jpg")

if imagen is not None:
    print("Dimensiones de la imagen:", imagen.shape)
else:
    print("No se pudo leer la imagen. Verifica la ruta o el archivo.")
