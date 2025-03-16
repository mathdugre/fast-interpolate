import os
from pathlib import Path

import imageio.v2 as imageio
import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
from tqdm import tqdm


def normalize(img):
    """Normalize the image for better visualization."""
    img = img - np.min(img)
    img = img / np.max(img)
    return img


def make_gif(out_file, files, *, slice_index=98, plane="sagittal", verbose=False):
    # Function to load a NIfTI file and extract a specific slice
    def load_nifti_slice(file_path, slice_index, plane):
        img = nib.load(file_path)
        data = img.get_fdata()
        data = normalize(data)
        match plane.lower():
            case "axial":
                return data[:, :, slice_index]
            case "sagittal":
                return data[slice_index, :, :]
            case "coronal":
                return data[:, slice_index, :]
            case _:
                raise ValueError(
                    "Invalid plane. Please choose 'axial', 'sagittal', or 'coronal'."
                )

    # Function to save a slice with annotation as an image
    def save_annotated_image(data, annotation, output_path):
        plt.imshow(data.T, cmap="gray", origin="lower")
        plt.title(annotation)
        plt.axis("off")
        plt.savefig(output_path, bbox_inches="tight", pad_inches=0)
        plt.close()

    # Directory to save temporary images
    temp_dir = "temp_images"
    os.makedirs(temp_dir, exist_ok=True)

    # List to store paths of the saved images
    image_paths = []

    # Load, annotate, and save each slice
    for i, (annotation, file_path) in enumerate(files.items()):
        slice_data = load_nifti_slice(
            file_path, slice_index, plane=plane
        )  # Change slice_index as needed
        image_path = os.path.join(temp_dir, f"image_{i}.png")
        save_annotated_image(slice_data, annotation, image_path)
        image_paths.append(image_path)

    # Create GIF
    images = [imageio.imread(image_path) for image_path in image_paths]
    imageio.mimsave(out_file, images, fps=2, loop=0)

    # Clean up temporary images
    for image_path in image_paths:
        os.remove(image_path)
    Path("temp_images").rmdir()

    if verbose:
        print(f"GIF saved as {out_file}")


warped_images = list(
    Path("dataset/ds004513/derivatives/flint/antsRegistration").rglob("Warped.nii.gz")
)
template = Path("tpl-MNI152NLin2009cAsym_res-01_desc-brain_T1w.nii.gz")
output_dir = Path("gifs/vrpec")

for image in tqdm(warped_images):
    for plane in ["sagittal", "coronal", "axial"]:
        exp_id = image.parent.parent.name
        subject_id = image.parent.name
        output_file = output_dir / exp_id / f"{plane}-{subject_id}.gif"
        output_file.parent.mkdir(exist_ok=True, parents=True)

        input_files = {
            f"{exp_id}: {subject_id}": image,
            "template": template,
        }
        make_gif(output_file, input_files, plane=plane)
