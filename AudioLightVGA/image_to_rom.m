% This program takes an image, resizes it and generates a .MIF file that
% can be loaded into a ROM or RAM
%
% Written by Daniel Leon-Salas

clear all;

fname_in      = '.\filter2.png';
fname_out     = '.\filter2.mif';

I = imread(fname_in);
figure; 
imagesc(I);
title('Original image');

W = 120;                        % width of resized image
H = 80;                         % height of resized image

I2 = imresize(I, [H W]);
figure; 
imagesc(I2);
title('Resized image');

[I3] = img2mif(I2, H, W, fname_out);

figure;
imagesc(I3/255);
title('Resized and color-quantized image');