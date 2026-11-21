#ifndef LIVESPLIT_CORE_H
#define LIVESPLIT_CORE_H

#ifdef __cplusplus
namespace LiveSplit {
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

void* Analysis_calculate_sum_of_best(void* run, bool simple_calculation, bool use_current_run, uint8_t method);
void* Analysis_calculate_total_playtime_for_run(void* run);
void* Analysis_calculate_total_playtime_for_timer(void* timer);

void AtomicDateTime_drop(void* self);
bool AtomicDateTime_is_synchronized(void* self);
char const* AtomicDateTime_to_rfc3339(void* self);

int32_t Attempt_index(void* self);
void* Attempt_time(void* self);
void* Attempt_pause_time(void* self);
void* Attempt_started(void* self);
void* Attempt_ended(void* self);

void* BlankSpaceComponent_new(void);
void BlankSpaceComponent_drop(void* self);
void* BlankSpaceComponent_into_generic(void* self);
char const* BlankSpaceComponent_state_as_json(void* self);
void* BlankSpaceComponent_state(void* self);

void BlankSpaceComponentState_drop(void* self);
uint32_t BlankSpaceComponentState_size(void* self);

void* CarouselComponent_new(void);
void CarouselComponent_drop(void* self);
void* CarouselComponent_into_generic(void* self);
size_t CarouselComponent_len(void* self);
uint32_t CarouselComponent_size(void* self);
uint64_t CarouselComponent_interval(void* self);
void CarouselComponent_add_component(void* self, void* component);
void CarouselComponent_set_size(void* self, uint32_t size);
void CarouselComponent_set_interval(void* self, uint64_t interval);

size_t CarouselComponentState_len(void* self);
char const* CarouselComponentState_component_type(void* self, size_t index);
uint32_t CarouselComponentState_size(void* self);
size_t CarouselComponentState_current_index(void* self);

void* CommandSink_from_timer(void* timer);
void CommandSink_drop(void* self);

void Component_drop(void* self);

void* CurrentComparisonComponent_new(void);
void CurrentComparisonComponent_drop(void* self);
void* CurrentComparisonComponent_into_generic(void* self);
char const* CurrentComparisonComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* CurrentComparisonComponent_state(void* self, void* timer, uint8_t lang);

void* CurrentPaceComponent_new(void);
void CurrentPaceComponent_drop(void* self);
void* CurrentPaceComponent_into_generic(void* self);
char const* CurrentPaceComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* CurrentPaceComponent_state(void* self, void* timer, uint8_t lang);

void* DeltaComponent_new(void);
void DeltaComponent_drop(void* self);
void* DeltaComponent_into_generic(void* self);
char const* DeltaComponent_state_as_json(void* self, void* timer, void* layout_settings, uint8_t lang);
void* DeltaComponent_state(void* self, void* timer, void* layout_settings, uint8_t lang);

void* DetailedTimerComponent_new(void);
void DetailedTimerComponent_drop(void* self);
void* DetailedTimerComponent_into_generic(void* self);
char const* DetailedTimerComponent_state_as_json(void* self, void* image_cache, void* timer, void* layout_settings, uint8_t lang);
void* DetailedTimerComponent_state(void* self, void* image_cache, void* timer, void* layout_settings, uint8_t lang);

void DetailedTimerComponentState_drop(void* self);
char const* DetailedTimerComponentState_timer_time(void* self);
char const* DetailedTimerComponentState_timer_fraction(void* self);
char const* DetailedTimerComponentState_timer_semantic_color(void* self);
char const* DetailedTimerComponentState_segment_timer_time(void* self);
char const* DetailedTimerComponentState_segment_timer_fraction(void* self);
bool DetailedTimerComponentState_comparison1_visible(void* self);
char const* DetailedTimerComponentState_comparison1_name(void* self);
char const* DetailedTimerComponentState_comparison1_time(void* self);
bool DetailedTimerComponentState_comparison2_visible(void* self);
char const* DetailedTimerComponentState_comparison2_name(void* self);
char const* DetailedTimerComponentState_comparison2_time(void* self);
char const* DetailedTimerComponentState_icon(void* self);
char const* DetailedTimerComponentState_display_icon(void* self);
char const* DetailedTimerComponentState_segment_name(void* self);

void* FuzzyList_new(void);
void FuzzyList_drop(void* self);
char const* FuzzyList_search(void* self, char const* pattern, size_t max);
void FuzzyList_push(void* self, char const* text);

void* GeneralLayoutSettings_default(void);
void GeneralLayoutSettings_drop(void* self);

void* GraphComponent_new(void);
void GraphComponent_drop(void* self);
void* GraphComponent_into_generic(void* self);
char const* GraphComponent_state_as_json(void* self, void* timer, void* layout_settings);
void* GraphComponent_state(void* self, void* timer, void* layout_settings);

void GraphComponentState_drop(void* self);
size_t GraphComponentState_points_len(void* self);
float GraphComponentState_point_x(void* self, size_t index);
float GraphComponentState_point_y(void* self, size_t index);
bool GraphComponentState_point_is_best_segment(void* self, size_t index);
size_t GraphComponentState_horizontal_grid_lines_len(void* self);
float GraphComponentState_horizontal_grid_line(void* self, size_t index);
size_t GraphComponentState_vertical_grid_lines_len(void* self);
float GraphComponentState_vertical_grid_line(void* self, size_t index);
float GraphComponentState_middle(void* self);
bool GraphComponentState_is_live_delta_active(void* self);
bool GraphComponentState_is_flipped(void* self);

void* GroupComponent_new(void);
void GroupComponent_drop(void* self);
void* GroupComponent_into_generic(void* self);
size_t GroupComponent_len(void* self);
uint32_t GroupComponent_size(void* self);
void GroupComponent_add_component(void* self, void* component);
void GroupComponent_set_size(void* self, uint32_t size);

size_t GroupComponentState_len(void* self);
char const* GroupComponentState_component_type(void* self, size_t index);
uint32_t GroupComponentState_size(void* self);

void* HotkeyConfig_new(void);
void* HotkeyConfig_parse_json(char const* settings);
void* HotkeyConfig_parse_file_handle(int64_t handle);
void HotkeyConfig_drop(void* self);
char const* HotkeyConfig_settings_description_as_json(void* self, uint8_t lang);
char const* HotkeyConfig_as_json(void* self);
bool HotkeyConfig_set_value(void* self, size_t index, void* value);

int32_t HotkeySystem_check_permission(void);
int32_t HotkeySystem_request_permission(void);
void* HotkeySystem_new(void* command_sink);
void* HotkeySystem_with_config(void* command_sink, void* config);
void HotkeySystem_drop(void* self);
void* HotkeySystem_config(void* self);
char const* HotkeySystem_resolve_key(void* self, char const* key_code, uint8_t lang);
char const* HotkeySystem_resolve_hotkey(void* self, char const* hotkey, uint8_t lang);
bool HotkeySystem_deactivate(void* self);
bool HotkeySystem_activate(void* self);
bool HotkeySystem_set_config(void* self, void* config);

void* ImageCache_new(void);
void ImageCache_drop(void* self);
void* ImageCache_lookup_data_ptr(void* self, char const* key);
size_t ImageCache_lookup_data_len(void* self, char const* key);
char const* ImageCache_cache(void* self, void* data, size_t len, bool is_large);
size_t ImageCache_collect(void* self);

void KeyValueComponentState_drop(void* self);
char const* KeyValueComponentState_key(void* self);
char const* KeyValueComponentState_value(void* self);
char const* KeyValueComponentState_semantic_color(void* self);

uint8_t Lang_parse_locale(char const* locale);
uint8_t Lang_from_name(char const* name);
char const* Lang_name(uint8_t lang);

void* Layout_new(void);
void* Layout_default_layout(uint8_t lang);
void* Layout_parse_json(char const* settings);
void* Layout_parse_file_handle(int64_t handle);
void* Layout_parse_original_livesplit(void* data, size_t length);
void Layout_drop(void* self);
void* Layout_clone(void* self);
char const* Layout_settings_as_json(void* self);
void* Layout_state(void* self, void* image_cache, void* timer, uint8_t lang);
void Layout_update_state(void* self, void* state, void* image_cache, void* timer, uint8_t lang);
char const* Layout_update_state_as_json(void* self, void* state, void* image_cache, void* timer, uint8_t lang);
char const* Layout_state_as_json(void* self, void* image_cache, void* timer, uint8_t lang);
void Layout_push(void* self, void* component);
void Layout_scroll_up(void* self);
void Layout_scroll_down(void* self);

void* LayoutEditor_new(void* layout);
void* LayoutEditor_close(void* self);
char const* LayoutEditor_state_as_json(void* self, void* image_cache, uint8_t lang);
void* LayoutEditor_state(void* self, void* image_cache, uint8_t lang);
char const* LayoutEditor_layout_state_as_json(void* self, void* image_cache, void* timer, uint8_t lang);
void LayoutEditor_update_layout_state(void* self, void* state, void* image_cache, void* timer, uint8_t lang);
char const* LayoutEditor_update_layout_state_as_json(void* self, void* state, void* image_cache, void* timer, uint8_t lang);
void LayoutEditor_select(void* self, size_t index);
void LayoutEditor_add_component(void* self, void* component);
void LayoutEditor_remove_component(void* self);
void LayoutEditor_move_component_up(void* self);
void LayoutEditor_move_component_down(void* self);
void LayoutEditor_move_component(void* self, size_t dst_index);
void LayoutEditor_duplicate_component(void* self);
void LayoutEditor_set_component_settings_value(void* self, size_t index, void* value);
void LayoutEditor_set_general_settings_value(void* self, size_t index, void* value, void* image_cache);

void LayoutEditorState_drop(void* self);
size_t LayoutEditorState_component_len(void* self);
char const* LayoutEditorState_component_text(void* self, size_t index);
uint8_t LayoutEditorState_buttons(void* self);
uint32_t LayoutEditorState_selected_component(void* self);
size_t LayoutEditorState_field_len(void* self, bool component_settings);
char const* LayoutEditorState_field_text(void* self, bool component_settings, size_t index);
void* LayoutEditorState_field_value(void* self, bool component_settings, size_t index);
uint32_t LayoutEditorState_component_indent_level(void* self, size_t index);
bool LayoutEditorState_component_is_placeholder(void* self, size_t index);
uint8_t LayoutEditorState_layout_direction(void* self);

void* LayoutState_new(void);
void LayoutState_drop(void* self);
char const* LayoutState_as_json(void* self);
size_t LayoutState_len(void* self);
char const* LayoutState_component_type(void* self, size_t index);
void* LayoutState_component_as_blank_space(void* self, size_t index);
void* LayoutState_component_as_detailed_timer(void* self, size_t index);
void* LayoutState_component_as_graph(void* self, size_t index);
void* LayoutState_component_as_key_value(void* self, size_t index);
void* LayoutState_component_as_separator(void* self, size_t index);
void* LayoutState_component_as_splits(void* self, size_t index);
void* LayoutState_component_as_text(void* self, size_t index);
void* LayoutState_component_as_timer(void* self, size_t index);
void* LayoutState_component_as_title(void* self, size_t index);
void* LayoutState_component_as_group(void* self, size_t index);
void* LayoutState_component_as_carousel(void* self, size_t index);

void* LinkedLayout_new(char const* path);
void LinkedLayout_drop(void* self);
bool LinkedLayout_is_default(void* self);
char const* LinkedLayout_path(void* self);

void ParseRunResult_drop(void* self);
void* ParseRunResult_unwrap(void* self);
bool ParseRunResult_parsed_successfully(void* self);
char const* ParseRunResult_timer_kind(void* self);
bool ParseRunResult_is_generic_timer(void* self);

void* PbChanceComponent_new(void);
void PbChanceComponent_drop(void* self);
void* PbChanceComponent_into_generic(void* self);
char const* PbChanceComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* PbChanceComponent_state(void* self, void* timer, uint8_t lang);

void* PossibleTimeSaveComponent_new(void);
void PossibleTimeSaveComponent_drop(void* self);
void* PossibleTimeSaveComponent_into_generic(void* self);
char const* PossibleTimeSaveComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* PossibleTimeSaveComponent_state(void* self, void* timer, uint8_t lang);

void PotentialCleanUp_drop(void* self);
char const* PotentialCleanUp_message(void* self);

void* PreviousSegmentComponent_new(void);
void PreviousSegmentComponent_drop(void* self);
void* PreviousSegmentComponent_into_generic(void* self);
char const* PreviousSegmentComponent_state_as_json(void* self, void* timer, void* layout_settings, uint8_t lang);
void* PreviousSegmentComponent_state(void* self, void* timer, void* layout_settings, uint8_t lang);

void* Run_new(void);
void* Run_parse(void* data, size_t length, char const* load_files_path);
void* Run_parse_file_handle(int64_t handle, char const* load_files_path);
void Run_drop(void* self);
void* Run_clone(void* self);
char const* Run_game_name(void* self);
void* Run_game_icon_ptr(void* self);
size_t Run_game_icon_len(void* self);
char const* Run_category_name(void* self);
char const* Run_extended_file_name(void* self, bool use_extended_category_name);
char const* Run_extended_name(void* self, bool use_extended_category_name);
char const* Run_extended_category_name(void* self, bool show_region, bool show_platform, bool show_variables);
uint32_t Run_attempt_count(void* self);
void* Run_metadata(void* self);
void* Run_offset(void* self);
size_t Run_len(void* self);
bool Run_has_been_modified(void* self);
void* Run_segment(void* self, size_t index);
size_t Run_segment_groups_len(void* self);
void* Run_segment_group(void* self, size_t index);
size_t Run_segments_len(void* self);
size_t Run_attempt_history_len(void* self);
void* Run_attempt_history_index(void* self, size_t index);
char const* Run_save_as_lss(void* self);
size_t Run_custom_comparisons_len(void* self);
char const* Run_custom_comparison(void* self, size_t index);
size_t Run_comparisons_len(void* self);
char const* Run_comparison(void* self, size_t index);
char const* Run_auto_splitter_settings(void* self);
void* Run_linked_layout(void* self);
void Run_push_segment(void* self, void* segment);
void Run_set_game_name(void* self, char const* game);
void Run_set_category_name(void* self, char const* category);
void Run_mark_as_modified(void* self);

void* RunEditor_new(void* run);
void* RunEditor_close(void* self);
char const* RunEditor_state_as_json(void* self, void* image_cache, uint8_t lang);
void RunEditor_select_timing_method(void* self, uint8_t method);
void RunEditor_unselect(void* self, size_t index);
void RunEditor_select_additionally(void* self, size_t index);
void RunEditor_select_range(void* self, size_t index);
void RunEditor_select_only(void* self, size_t index);
void RunEditor_set_game_name(void* self, char const* game);
void RunEditor_set_category_name(void* self, char const* category);
bool RunEditor_parse_and_set_offset(void* self, char const* offset, uint8_t lang);
bool RunEditor_parse_and_set_attempt_count(void* self, char const* attempts);
void RunEditor_set_game_icon(void* self, void* data, size_t length);
void RunEditor_remove_game_icon(void* self);
void RunEditor_set_linked_layout(void* self, void* linked_layout);
void RunEditor_remove_linked_layout(void* self);
void RunEditor_set_run_id(void* self, char const* name);
void RunEditor_set_region_name(void* self, char const* name);
void RunEditor_set_platform_name(void* self, char const* name);
void RunEditor_set_emulator_usage(void* self, bool uses_emulator);
void RunEditor_set_speedrun_com_variable(void* self, char const* name, char const* value);
void RunEditor_remove_speedrun_com_variable(void* self, char const* name);
void RunEditor_add_custom_variable(void* self, char const* name);
void RunEditor_set_custom_variable(void* self, char const* name, char const* value);
void RunEditor_remove_custom_variable(void* self, char const* name);
void RunEditor_clear_metadata(void* self);
void RunEditor_insert_segment_above(void* self);
void RunEditor_insert_segment_below(void* self);
void RunEditor_remove_segments(void* self);
void RunEditor_move_segments_up(void* self);
void RunEditor_move_segments_down(void* self);
bool RunEditor_create_segment_group_from_selection(void* self, char const* name);
bool RunEditor_select_segment_group(void* self, size_t group_index);
bool RunEditor_toggle_segment_group_selection(void* self, size_t group_index);
bool RunEditor_select_segment_group_range(void* self, size_t group_index);
bool RunEditor_remove_selected_segment_groups(void* self);
bool RunEditor_rename_segment_group(void* self, size_t group_index, char const* name);
bool RunEditor_set_segment_group_icon(void* self, size_t group_index, void* data, size_t length);
bool RunEditor_remove_segment_group_icon(void* self, size_t group_index);
void RunEditor_active_set_icon(void* self, void* data, size_t length);
void RunEditor_active_remove_icon(void* self);
void RunEditor_active_set_name(void* self, char const* name);
bool RunEditor_active_parse_and_set_split_time(void* self, char const* time, uint8_t lang);
bool RunEditor_active_parse_and_set_segment_time(void* self, char const* time, uint8_t lang);
bool RunEditor_active_parse_and_set_best_segment_time(void* self, char const* time, uint8_t lang);
bool RunEditor_active_parse_and_set_comparison_time(void* self, char const* comparison, char const* time, uint8_t lang);
bool RunEditor_add_comparison(void* self, char const* comparison);
bool RunEditor_import_comparison(void* self, void* run, char const* comparison);
void RunEditor_remove_comparison(void* self, char const* comparison);
bool RunEditor_rename_comparison(void* self, char const* old_name, char const* new_name);
bool RunEditor_move_comparison(void* self, size_t src_index, size_t dst_index);
bool RunEditor_parse_and_generate_goal_comparison(void* self, char const* time, uint8_t lang);
bool RunEditor_copy_comparison(void* self, char const* old_name, char const* new_name);
void RunEditor_clear_history(void* self);
void RunEditor_clear_times(void* self);
void* RunEditor_clean_sum_of_best(void* self, uint8_t lang);

char const* RunMetadata_run_id(void* self);
char const* RunMetadata_platform_name(void* self);
bool RunMetadata_uses_emulator(void* self);
char const* RunMetadata_region_name(void* self);
void* RunMetadata_speedrun_com_variables(void* self);
void* RunMetadata_custom_variables(void* self);

void RunMetadataCustomVariable_drop(void* self);
char const* RunMetadataCustomVariable_name(void* self);
char const* RunMetadataCustomVariable_value(void* self);
bool RunMetadataCustomVariable_is_permanent(void* self);

void RunMetadataCustomVariablesIter_drop(void* self);
void* RunMetadataCustomVariablesIter_next(void* self);

void RunMetadataSpeedrunComVariable_drop(void* self);
char const* RunMetadataSpeedrunComVariable_name(void* self);
char const* RunMetadataSpeedrunComVariable_value(void* self);

void RunMetadataSpeedrunComVariablesIter_drop(void* self);
void* RunMetadataSpeedrunComVariablesIter_next(void* self);

void* Segment_new(char const* name);
void Segment_drop(void* self);
char const* Segment_name(void* self);
void* Segment_icon_ptr(void* self);
size_t Segment_icon_len(void* self);
void* Segment_comparison(void* self, char const* comparison);
void* Segment_personal_best_split_time(void* self);
void* Segment_best_segment_time(void* self);
void* Segment_segment_history(void* self);

size_t SegmentGroup_start(void* self);
size_t SegmentGroup_end(void* self);
char const* SegmentGroup_name(void* self);
void* SegmentGroup_icon_ptr(void* self);
size_t SegmentGroup_icon_len(void* self);

void* SegmentHistory_iter(void* self);

int32_t SegmentHistoryElement_index(void* self);
void* SegmentHistoryElement_time(void* self);

void SegmentHistoryIter_drop(void* self);
void* SegmentHistoryIter_next(void* self);

void* SegmentTimeComponent_new(void);
void SegmentTimeComponent_drop(void* self);
void* SegmentTimeComponent_into_generic(void* self);
char const* SegmentTimeComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* SegmentTimeComponent_state(void* self, void* timer, uint8_t lang);

void* SeparatorComponent_new(void);
void SeparatorComponent_drop(void* self);
void* SeparatorComponent_into_generic(void* self);
void* SeparatorComponent_state(void* self);

void SeparatorComponentState_drop(void* self);

void* SettingValue_from_bool(bool value);
void* SettingValue_from_uint(uint32_t value);
void* SettingValue_from_optional_uint(uint32_t value);
void* SettingValue_from_optional_empty_uint(void);
void* SettingValue_from_int(int32_t value);
void* SettingValue_from_string(char const* value);
void* SettingValue_from_optional_string(char const* value);
void* SettingValue_from_optional_empty_string(void);
void* SettingValue_from_accuracy(char const* value);
void* SettingValue_from_digits_format(char const* value);
void* SettingValue_from_optional_timing_method(char const* value);
void* SettingValue_from_optional_empty_timing_method(void);
void* SettingValue_from_color(float r, float g, float b, float a);
void* SettingValue_from_optional_color(float r, float g, float b, float a);
void* SettingValue_from_optional_empty_color(void);
void* SettingValue_from_transparent_gradient(void);
void* SettingValue_from_vertical_gradient(float r1, float g1, float b1, float a1, float r2, float g2, float b2, float a2);
void* SettingValue_from_horizontal_gradient(float r1, float g1, float b1, float a1, float r2, float g2, float b2, float a2);
void* SettingValue_from_alternating_gradient(float r1, float g1, float b1, float a1, float r2, float g2, float b2, float a2);
void* SettingValue_from_alignment(char const* value);
void* SettingValue_from_column_kind(char const* value);
void* SettingValue_from_column_start_with(char const* value);
void* SettingValue_from_column_update_with(char const* value);
void* SettingValue_from_column_update_trigger(char const* value);
void* SettingValue_from_subsplit_display_mode(char const* value);
void* SettingValue_from_icon_display_mode(char const* value);
void* SettingValue_from_layout_direction(char const* value);
void* SettingValue_from_font(char const* family, char const* style, char const* weight, char const* stretch);
void* SettingValue_from_empty_font(void);
void* SettingValue_from_delta_gradient(char const* value);
void* SettingValue_from_background_image(char const* image_id, float brightness, float opacity, float blur);
void SettingValue_drop(void* self);
char const* SettingValue_as_json(void* self);

void SharedTimer_drop(void* self);
void* SharedTimer_share(void* self);
void* SharedTimer_read(void* self);
void* SharedTimer_write(void* self);
void SharedTimer_replace_inner(void* self, void* timer);

void* SplitsComponent_new(uint8_t lang);
void SplitsComponent_drop(void* self);
void* SplitsComponent_into_generic(void* self);
char const* SplitsComponent_state_as_json(void* self, void* image_cache, void* timer, void* layout_settings, uint8_t lang);
void* SplitsComponent_state(void* self, void* image_cache, void* timer, void* layout_settings, uint8_t lang);
void SplitsComponent_scroll_up(void* self);
void SplitsComponent_scroll_down(void* self);
void SplitsComponent_set_visual_split_count(void* self, size_t count);
void SplitsComponent_set_split_preview_count(void* self, size_t count);
void SplitsComponent_set_always_show_last_split(void* self, bool always_show_last_split);
void SplitsComponent_set_show_gap_separators(void* self, bool show_gap_separators);

void SplitsComponentState_drop(void* self);
size_t SplitsComponentState_len(void* self);
char const* SplitsComponentState_icon(void* self, size_t index);
char const* SplitsComponentState_name(void* self, size_t index);
size_t SplitsComponentState_columns_len(void* self, size_t index);
char const* SplitsComponentState_column_value(void* self, size_t index, size_t column_index);
char const* SplitsComponentState_column_semantic_color(void* self, size_t index, size_t column_index);
bool SplitsComponentState_is_current_split(void* self, size_t index);
bool SplitsComponentState_is_scrolled_to_split(void* self, size_t index);
bool SplitsComponentState_is_indented(void* self, size_t index);
bool SplitsComponentState_separator_before(void* self, size_t index);
size_t SplitsComponentState_section_index(void* self, size_t index);
bool SplitsComponentState_has_column_labels(void* self);
char const* SplitsComponentState_column_label(void* self, size_t index);

void SumOfBestCleaner_drop(void* self);
void* SumOfBestCleaner_next_potential_clean_up(void* self);
void SumOfBestCleaner_apply(void* self, void* clean_up);

void* SumOfBestComponent_new(void);
void SumOfBestComponent_drop(void* self);
void* SumOfBestComponent_into_generic(void* self);
char const* SumOfBestComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* SumOfBestComponent_state(void* self, void* timer, uint8_t lang);

void* TextComponent_new(void);
void TextComponent_drop(void* self);
void* TextComponent_into_generic(void* self);
char const* TextComponent_state_as_json(void* self, void* timer);
void* TextComponent_state(void* self, void* timer);
void TextComponent_use_variable(void* self, char const* variable, bool split);
void TextComponent_set_center(void* self, char const* text);
void TextComponent_set_left(void* self, char const* text);
void TextComponent_set_right(void* self, char const* text);

void TextComponentState_drop(void* self);
char const* TextComponentState_left(void* self);
char const* TextComponentState_right(void* self);
char const* TextComponentState_center(void* self);
bool TextComponentState_is_split(void* self);

void Time_drop(void* self);
void* Time_clone(void* self);
void* Time_real_time(void* self);
void* Time_game_time(void* self);
void* Time_index(void* self, uint8_t timing_method);

void* TimeSpan_from_seconds(double seconds);
void* TimeSpan_parse(char const* text, uint8_t lang);
void TimeSpan_drop(void* self);
void* TimeSpan_clone(void* self);
double TimeSpan_total_seconds(void* self);
int64_t TimeSpan_whole_seconds(void* self);
int32_t TimeSpan_subsec_nanoseconds(void* self);
void TimeSpan_add_assign(void* self, void* other);

void* Timer_new(void* run);
void* Timer_into_shared(void* self);
void* Timer_into_run(void* self, bool update_splits);
void Timer_drop(void* self);
ssize_t Timer_current_split_index(void* self);
bool Timer_current_attempt_has_new_best_times(void* self);
uint8_t Timer_current_timing_method(void* self);
char const* Timer_current_comparison(void* self);
bool Timer_is_game_time_initialized(void* self);
bool Timer_is_game_time_paused(void* self);
void* Timer_loading_times(void* self);
uint8_t Timer_current_phase(void* self);
void* Timer_get_run(void* self);
char const* Timer_save_as_lss(void* self);
void Timer_print_debug(void* self);
void* Timer_current_time(void* self);
bool Timer_replace_run(void* self, void* run, bool update_splits);
void* Timer_set_run(void* self, void* run);
int32_t Timer_start(void* self);
int32_t Timer_split(void* self);
int32_t Timer_split_or_start(void* self);
int32_t Timer_skip_split(void* self);
int32_t Timer_undo_split(void* self);
int32_t Timer_reset(void* self, bool update_splits);
int32_t Timer_reset_and_set_attempt_as_pb(void* self);
int32_t Timer_pause(void* self);
int32_t Timer_resume(void* self);
int32_t Timer_toggle_pause(void* self);
int32_t Timer_toggle_pause_or_start(void* self);
int32_t Timer_undo_all_pauses(void* self);
void Timer_set_current_timing_method(void* self, uint8_t method);
void Timer_toggle_timing_method(void* self);
int32_t Timer_set_current_comparison(void* self, char const* comparison);
void Timer_switch_to_next_comparison(void* self);
void Timer_switch_to_previous_comparison(void* self);
int32_t Timer_initialize_game_time(void* self);
void Timer_deinitialize_game_time(void* self);
int32_t Timer_pause_game_time(void* self);
int32_t Timer_resume_game_time(void* self);
int32_t Timer_set_game_time(void* self, void* time);
int32_t Timer_set_loading_times(void* self, void* time);
void Timer_set_custom_variable(void* self, char const* name, char const* value);
void Timer_mark_as_unmodified(void* self);

void* TimerComponent_new(void);
void TimerComponent_drop(void* self);
void* TimerComponent_into_generic(void* self);
char const* TimerComponent_state_as_json(void* self, void* timer, void* layout_settings, uint8_t lang);
void* TimerComponent_state(void* self, void* timer, void* layout_settings, uint8_t lang);

void TimerComponentState_drop(void* self);
char const* TimerComponentState_time(void* self);
char const* TimerComponentState_fraction(void* self);
char const* TimerComponentState_time_size_hint(void* self);
char const* TimerComponentState_fraction_size_hint(void* self);
char const* TimerComponentState_semantic_color(void* self);

void TimerReadLock_drop(void* self);
void* TimerReadLock_timer(void* self);

void TimerWriteLock_drop(void* self);
void* TimerWriteLock_timer(void* self);

void* TitleComponent_new(void);
void TitleComponent_drop(void* self);
void* TitleComponent_into_generic(void* self);
char const* TitleComponent_state_as_json(void* self, void* image_cache, void* timer, uint8_t lang);
void* TitleComponent_state(void* self, void* image_cache, void* timer, uint8_t lang);

void TitleComponentState_drop(void* self);
char const* TitleComponentState_icon(void* self);
char const* TitleComponentState_line1(void* self);
char const* TitleComponentState_line2(void* self);
bool TitleComponentState_is_centered(void* self);
bool TitleComponentState_shows_finished_runs(void* self);
uint32_t TitleComponentState_finished_runs(void* self);
bool TitleComponentState_shows_attempts(void* self);
uint32_t TitleComponentState_attempts(void* self);

void* TotalPlaytimeComponent_new(void);
void TotalPlaytimeComponent_drop(void* self);
void* TotalPlaytimeComponent_into_generic(void* self);
char const* TotalPlaytimeComponent_state_as_json(void* self, void* timer, uint8_t lang);
void* TotalPlaytimeComponent_state(void* self, void* timer, uint8_t lang);

#ifdef __cplusplus
}
}
#endif

#endif
