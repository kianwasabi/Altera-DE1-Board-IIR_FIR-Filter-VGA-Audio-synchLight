function [img_out] = img2mif(img, H, W, outfile)
% Creates .mif file from input image: img
% .mif file contains 8-bit words (bytes)
% color byte: [R2,R1,R0,G2,G1,G0,B1,B0]
% img = img2mif(img, H, W, outfile)
% img = array of size H, W with input image
% outfile = output .mif file

fid = fopen(outfile,'wb');     %  opens the output file

fprintf(fid,'-- VGA Memory Map\n');
fprintf(fid,'DEPTH = %d;\n', H*W);
fprintf(fid,'WIDTH = 8;\n');
fprintf(fid,'ADDRESS_RADIX = HEX;\n'); 
fprintf(fid,'DATA_RADIX = BIN;\n');
fprintf(fid,'CONTENT\n');
fprintf(fid,'BEGIN\n\n');

cnt = 0;
img_out = zeros(H, W, 3);
for r=1:H
    for c=1:W
        cnt = cnt + 1;
        R = img(r,c,1);
        G = img(r,c,2);
        B = img(r,c,3);
        Rb = dec2bin(double(R),8);
        Gb = dec2bin(double(G),8);
        Bb = dec2bin(double(B),8);
        outbyte = [ Rb(1:3) Gb(1:3) Bb(1:2) ];
        img_out(r,c,1) = bin2dec([Rb(1:3) '00000']);
        img_out(r,c,2) = bin2dec([Gb(1:3) '00000']);
        img_out(r,c,3) = bin2dec([Bb(1:2) '000000']);
        fprintf(fid, '%s : %s;\n', dec2hex((r-1)*W + c - 1,4), outbyte);
    end
end

fprintf(fid,'\nEND;\n');
fclose(fid);
