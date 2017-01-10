;+
; NAME:
;
;       Topo_advanced_vis_mixer
;
; PURPOSE:
;
;       Producing image that combines multiple visualizations in one image.
;
; INPUTS:
;       in_img_file: in, required, type=string
;           Full path (folder + filename) to the original image file.
;       miser_config: in, required, type=
;           structure
;       file_format: in, required, type=string
;           Output image format.
;       log_file: in, required, type=string
;           Full path to the txt file where log for this procedure will be stored.
;
; KEYWORDS:
;       out_img_file: out, optional, type=string
;           Full path (folder + filename) to the output image file.
;       lzw_tiff: in, optional, type=boolean
;           If set generated tif image will be compressed by LZW compression standard.
;       envi_interleave: in, optional, type=string
;           Controls how the output ENVI file will be interleaved (BSQ, BIP, BIL).
;       jp2000_quality: in, optional, type=byte
;           JP2000 quality percentage between 0 and 100. A value of 50 means the file will be half-size in comparison to
;           uncompressed data, 33 means 1/3, etc..
;       jp2000_lossless: in, optional, type=boolean
;           If enabled image will be compressed by lossless compression algorithm.
;       jpg_quality: in, optional, type=byte
;           JPEG compression values must be in the range 10-100. Low values result in higher compression ratios, but
;           poorer image quality. Values above 95 are not meaningfully better quality but can but substantially larger.
;       erdas_compression: in, optional, type=boolean
;           If enabled output image will be compressed using spill file disables compression.
;       erdas_statistics: in, optional, type=boolean
;           If enabled statistics and a histogram will be generated and stored into image file.
;       error: out, optional, type=string
;           Output error message that was generated by GDAL library.
;
; OUTPUTS:
;
;       Image in the selected output file format. 
;       It has the same name and path as the input image with'_VIS' appended ('_VIS_ N' where the visualization used is preset visualization)
;       the only difference is in the file extension.
;
; AUTHOR:
;
;       Maja Somrak
;
; DEPENDENCIES:
;
;       GDAL
;       programrootdir
;
; MODIFICATION HISTORY:
;
;       1.0  December 2016: Initial version written by Maja Somrak
;-
pro topo_advanced_vis_mixer

end

function create_new_mixer_layer, VISUALIZATION = visualization, BLEND_MODE = blend_mode, OPACITY = opacity, p_wdgt_state = p_wdgt_state
  if (KEYWORD_SET(VISUALIZATION)) then begin
    if (~KEYWORD_SET(BLEND_MODE)) then blend_mode = 'Normal'
    if (~KEYWORD_SET(OPACITY)) then opacity = 100
    min = get_min_default(visualization, p_wdgt_state)
    max = get_max_default(visualization, p_wdgt_state)
    normalization =  get_norm_default(visualization, p_wdgt_state)
    return, create_struct('vis', visualization, 'normalization', normalization, 'min', min, 'max', max, 'blend_mode', blend_mode, 'opacity', opacity)
  endif
  return, create_struct('vis', '<none>', 'normalization', 'Lin', 'min', '', 'max', '', 'blend_mode', 'Normal', 'opacity', 100)
end

function limit_combinations, all_combinations, nr_combinations
  if (nr_combinations LT all_combinations.length) then begin
    all_combinations = all_combinations[0:nr_combinations-1]
  endif
  return, all_combinations
end

function combination_bottom_layer_validate, combination
  no_blend_mode = 'Normal'
  max_opacity = 100

  for layer=combination.layers.length-1,0,-1 do begin
    visualization = combination.layers[layer].vis
    if (visualization EQ '<none>') then continue
    combination.layers[layer].blend_mode = no_blend_mode  ; set blend_mode to 'Normal'
    combination.layers[layer].opacity = max_opacity       ; set opacity to max
    break
  endfor

  return, combination
end

function all_combinations_bottom_layer_validate, all_combinations
  for i=0,all_combinations.length-1 do begin
    all_combinations[i] = combination_bottom_layer_validate(all_combinations[i])
  endfor
  return, all_combinations
end

function extract_parameter_string, parameters, parameter_name
  combination_layer = create_new_mixer_layer()

  ; indexes of pairs 'parameter:value', split by semicolon
  parameter = 0
  value = 1

  ; indexes in array of line splits for parameters
  keys = ['layer', 'vis', 'norm', 'min', 'max', 'blend_mode', 'opacity']
  indexes = [0,1,2,3,4,5,6]
  idx = HASH(keys, indexes)
  
  pair = strsplit(parameters[idx[parameter_name]], ':', /EXTRACT)
; unnecessary
;  foreach str, pair do begin
;    str = strtrim(str, 2)
;  endforeach
  
  if (strtrim(pair[parameter],2) EQ parameter_name AND (pair.length GT 1)) then return, strtrim(pair[value],2)
  print, 'There is no value given for a selected parameter!'
  return, ''

end

function parse_layer, parameters
  combination_layer = create_new_mixer_layer()

  ; visualization
  combination_layer.vis = extract_parameter_string(parameters, 'vis')

  if (combination_layer.vis NE '<none>') then begin
    
    combination_layer.normalization = extract_parameter_string(parameters, 'norm')
    if (combination_layer.normalization EQ '') then combination_layer.normalization = get_norm_default(combination_layer.vis, p_wdgt_state)

    combination_layer.min = float(extract_parameter_string(parameters, 'min'))
    if (combination_layer.min EQ '') then combination_layer.min = get_min_default(combination_layer.vis, p_wdgt_state)
    
    combination_layer.max = float(extract_parameter_string(parameters, 'max'))
    if (combination_layer.max EQ '') then combination_layer.max = get_max_default(combination_layer.vis, p_wdgt_state)
    
    
    ;    min_str = extract_parameter_string(parameters, 'min')
    ;    if (min_str NE '') then begin
    ;      combination_layer.min = float(min_str)
    ;     endif else begin
    ;        combination_layer.min = get_min_default(combination_layer.vis, )
    ;     endelse
    ;    max_str = extract_parameter_string(parameters, 'max')
    ;     if (max_str NE '') then begin
    ;       combination_layer.max = float(min_str)
    ;     endif else begin
    ;       combination_layer.max = get_max_default(combination_layer.vis, )
    ;     endelse
    
    combination_layer.blend_mode = extract_parameter_string(parameters, 'blend_mode')
    if (combination_layer.blend_mode EQ '') then combination_layer.blend_mode = 'Normal'
    combination_layer.opacity = fix(extract_parameter_string(parameters, 'opacity'))
  endif
  
  return, combination_layer
end

function parse_combination, combination_name, array
   combination = gen_combination(combination_name, array.length)
   
   for i=0,array.length-1 do begin
      ; split line into parameter:value chunks
      parameters = strsplit(array[i], ',', /EXTRACT)
      ; parse layer with parameters   
      combination.layers[i] = parse_layer(parameters)
      ; number of layer
      layer_nr = fix(extract_parameter_string(parameters, 'layer'))
      ; check
      if (i+1 NE layer_nr) then print, 'Layer numbers do not match! Please check default_settings_combinations file! '
   endfor
   return, combination
end

function parse_min_max, lines
  ; hashmaps:
  ;   keys = vis_droplist -> but it is read from file not generated from vis_droplist
  ;   indexes = default min/max
  
  def_min = HASH()
  def_max = HASH()
  section = 0

  for i=0,lines.length-1 do begin
    line = strtrim(lines[i], 2)

    if (strmatch(line,'# SECTION*', /FOLD_CASE)) then section++
    if (section NE 1) then continue
    
    if (line EQ '' OR strmatch(line,'#*', /FOLD_CASE)) then begin
      print, 'Line not to be parsed: ', line
      continue
    endif 
    
    splitted = strsplit(line, ',', /EXTRACT)
    visualization = strtrim(splitted[0],2)
    parameter = strtrim(splitted[1],2)
    default_value = strtrim(splitted[2],2)
    
    case parameter of
      'min': def_min += HASH(visualization, default_value)
      'max': def_max += HASH(visualization, default_value)
    endcase
  endfor

  return, create_struct('min_hash', def_min, 'max_hash', def_max)
end

function parse_combinations_from_lines, lines
  all_combinations = []
  
  ; init
  title = ''
  array = []
  nr = 0
  section = 0

  for i=0,lines.length-1 do begin
    line = strtrim(lines[i], 2)
    
    if (strmatch(line,'# SECTION*')) then section++
    
    if (section NE 2) then continue

    ; skip empty lines and comments
    if (line EQ '' OR strmatch(line,'#*', /FOLD_CASE)) then begin
       print, 'Line not to be parsed: ', line
    endif else begin
      
      ; (A) new combination
      if (strmatch(line,'combination*', /FOLD_CASE)) then begin
        
         if (array NE !NULL) then begin
           if (array.length GT 0) then begin
            ; parse combination in array
            new_combination = parse_combination(title, array)
            all_combinations = [all_combinations, new_combination] 
            
            ;SET PARAMETERS FOR NEXT COMBINATION
            ; sequential number
            nr = nr+1
          endif
        endif
        
        ;SET PARAMETERS FOR NEXT COMBINATION
        ; title .... in this line is for next combination
        splitted = strsplit(line, '=', /EXTRACT)
        if (strtrim(splitted[0],2) EQ 'combination') then begin
          title = strtrim(splitted[1],2)    
        endif   
        ; reset array of layers
        array = []
      endif

      ; (B) still same combination, new layer - put layer in array
      if (strmatch(line,'layer:*', /FOLD_CASE)) then begin
         array = [array, line]
      endif
      
    endelse
  endfor
  
   if (array NE !NULL) then begin
      if (array.length GT 0) then begin
          new_combination = parse_combination(title, array)
          all_combinations = [all_combinations, new_combination] 
      endif
  endif
  
  all_combinations = all_combinations_bottom_layer_validate(all_combinations)
  
  return, all_combinations
end

function read_combinations_from_file, file_path
  if file_test(file_path) then begin
    n_lines = file_lines(file_path)

    if n_lines gt 0 then begin
      lines = make_array(n_lines, /string)
      openr, fu, file_path, /get_lun
      readf, fu, lines
      free_lun, fu

      return, parse_combinations_from_lines(lines)
    endif
  endif
  return, 0
end

function read_default_min_max_from_file, file_path
  if file_test(file_path) then begin
    n_lines = file_lines(file_path)

    if n_lines gt 0 then begin
      lines = make_array(n_lines, /string)
      openr, fu, file_path, /get_lun
      readf, fu, lines
      free_lun, fu

      return, parse_min_max(lines)
    endif
  endif
  return, 0
end


;=========================================================================================================
;=== Read program settings from COMBINATIONS settings file or sav file between sessions ==================
;=========================================================================================================

;settings_folder = programrootdir()+'settings'

;function read_combination_settings, settings_folder
;  temp_comb_sav = settings_folder + '\temp_combination_settings.sav'
;  if keyword_set(re_run) and file_test(temp_comb_sav) then begin
;    restore, temp_comb_sav
;  endif else begin
;    comb_file = settings_folder +'\default_settings_combinations.txt'
;    
;    if file_test(comb_file) then combination_settings = get_settings_combinations(comb_file) $
;    else combination_settings = create_struct('none','none')
;    combination_settings_tags = strlowcase(tag_names(combination_settings))
;  
;    if test_tag('overwrite', combination_settings_tags) then overwrite = combination_settings.overwrite $
;    else overwrite = 1.0
;  
;    if test_tag('Analytical hillshading - min') then 
;    
;    else 
;   
;    if test_tag('min_limit', settings_tags) then min_radius = input_settings.min_radius $
;    else min_radius = 2
;    if test_tag('max_limit', settings_tags) then max_radius = input_settings.max_radius $
;    else max_radius = 0
;  
;  
;    process_file = programrootdir()+'settings\process_files.txt'
;    if file_test(process_file) then begin
;      n_lines = file_lines(process_file)
;      if n_lines gt 0 then begin
;        files_to_process = make_array(n_lines, /string)
;        openr, txt_proc, process_file, /get_lun
;        readf, txt_proc, files_to_process
;        free_lun, txt_proc
;        skip_gui = 1
;      endif
;    endif
;    
;    
;  endelse
;end