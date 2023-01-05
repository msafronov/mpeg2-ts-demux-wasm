(module
    (import "env" "log" (func $log (param i32)))

    (memory (export "memory") 0x00 0xFF)


    ;; ----------------------------------------------------
    ;; globals
    ;; ----------------------------------------------------

    (global $memory_wasm_page_byte_count i32 (i32.const 0x10000))
    (global $memory_cursor (mut i32) (i32.const 0x00))
    (global $memory_cursor_offset (mut i32) (i32.const 0x00))
    (global $memory_segment_offset (export "s_offset") (mut i32) (i32.const 0x00))
    (global $memory_segment_length (export "s_len") (mut i32) (i32.const 0x00))
    (global $memory_es_video_offset (export "v_es_offset") (mut i32) (i32.const 0x00))
    (global $memory_es_video_length (export "v_es_len") (mut i32) (i32.const 0x00))
    (global $memory_es_audio_offset (export "a_es_offset") (mut i32) (i32.const 0x00))
    (global $memory_es_audio_length (export "a_es_len") (mut i32) (i32.const 0x00))

    (global $stream_types_count i32 (i32.const 0x03))

    (global $transport_packet_size i32 (i32.const 0xBC))
    (global $transport_packet_header_size i32 (i32.const 0x04))
    (global $transport_packet_sync_byte i32 (i32.const 0x47))
    (global $transport_packet_pid (mut i32) (i32.const 0x00))
    (global $transport_packet_payload_unit_start_indicator (mut i32) (i32.const 0x00))

    ;; 0x00 => "00" Reserved for future use by ISO/IEC
    ;; 0x10 => "01" No adaptation_field, payload only
    ;; 0x20 => "10" Adaptation_field only, no payload
    ;; 0x30 => "11" Adaptation_field followed by payload
    (global $transport_packet_adaptation_field_control (mut i32) (i32.const 0x00))

    (global $adaptation_field_length (mut i32) (i32.const 0x00))

    (global $pat_program_map_pid (mut i32) (i32.const -0x01))

    (global $pmt_elementary_pid_video (mut i32) (i32.const -0x01))
    (global $pmt_elementary_pid_audio (mut i32) (i32.const -0x01))


    ;; ----------------------------------------------------
    ;; public api
    ;; ----------------------------------------------------

    (func $malloc (export "malloc") (param $segment_buffer_length i32) (result i32)
        (local $memory_blocks_for_segment_buffer i32)

        ;; memory allocation is not necessary when new buffer is smaller than existing buffer
        (i32.le_u
            (local.get $segment_buffer_length)
            (global.get $memory_segment_length))

        (if
            (then
                (global.set
                    $memory_segment_length
                    (local.get $segment_buffer_length))

                (return (i32.const 1))
            )
        )

        ;; memory allocation for new segment buffer length
        (local.set
            $memory_blocks_for_segment_buffer
            (i32.trunc_f32_u
                (f32.ceil
                    (f32.div
                        (f32.convert_i32_u
                            (local.get $segment_buffer_length))
                        (f32.convert_i32_u
                            (global.get $memory_wasm_page_byte_count))))))

        (memory.grow
            (i32.sub
                (i32.mul
                    (local.get $memory_blocks_for_segment_buffer)
                    (global.get $stream_types_count))

                (memory.size)))

        i32.const -1
        i32.eq

        (if
            (then
                ;; error
                ;; TODO: error system
                (return (i32.const 0))
            )
        )

        ;; segment length updating
        (global.set
            $memory_segment_length
            (local.get $segment_buffer_length))

        ;; video offset and length updating
        (global.set $memory_es_video_offset
            (i32.mul
                (local.get $memory_blocks_for_segment_buffer)
                (global.get $memory_wasm_page_byte_count)))

        (global.set $memory_es_video_length
            (i32.const 0x00))

        ;; audio offset and length updating
        (global.set $memory_es_audio_offset
            (i32.mul
                (i32.mul
                    (local.get $memory_blocks_for_segment_buffer)
                    (i32.const 0x02))
                (global.get $memory_wasm_page_byte_count)))

        (global.set $memory_es_audio_length
            (i32.const 0x00))

        ;; success
        i32.const 1
    )

    (func $demux (export "demux")
        (loop $demux_loop
            ;; sync byte checking
            (i32.eq
                (i32.load8_u (global.get $memory_cursor))
                (global.get $transport_packet_sync_byte))

            (if
                (then
                    (global.set
                        $memory_cursor_offset
                        (global.get $memory_cursor))

                    (call $transport_packet
                        (global.get $memory_cursor_offset))

                    (call $memory_cursor_offset_increase_by
                        (i32.const 0x04))

                    (call $adaptation_field
                        (global.get $memory_cursor_offset))

                    ;; skip adaption field if necessary
                    (call $memory_cursor_offset_increase_by
                        (call $adaptation_field_get_skip_offset))

                    ;; psi processing

                    ;; pat
                    (i32.eq
                        (global.get $transport_packet_pid)
                        (i32.const 0x00))

                    (if
                        (then
                            (call $pat
                                (global.get $memory_cursor_offset))
                        )
                    )

                    ;; pmt
                    (i32.eq
                        (global.get $transport_packet_pid)
                        (global.get $pat_program_map_pid))

                    (if
                        (then
                            (call $pmt
                                (global.get $memory_cursor_offset))
                        )
                    )

                    ;; pes

                    ;; video
                    (i32.eq
                        (global.get $transport_packet_pid)
                        (global.get $pmt_elementary_pid_video))

                    (if
                        (then
                            (call $pes
                                (global.get $memory_cursor_offset))
                        )
                    )

                    ;; audio
                    (i32.eq
                        (global.get $transport_packet_pid)
                        (global.get $pmt_elementary_pid_audio))

                    (if
                        (then
                            (call $pes
                                (global.get $memory_cursor_offset))
                        )
                    )

                    ;; demux loop continuation
                    (global.set
                        $memory_cursor
                        (i32.add
                            (global.get $memory_cursor)
                            (global.get $transport_packet_size)))

                    br $demux_loop
                )
            )
        )
    )


    ;; ----------------------------------------------------
    ;; transport packet
    ;; ----------------------------------------------------

    (func $transport_packet (param $offset i32)
        ;; PID
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x01)))
                    (i32.const 0x1F))
                (i32.const 0x08))

            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x02))))

        global.set $transport_packet_pid

        ;; payload_unit_start_indicator
        (i32.and
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x01)))
            (i32.const 0x40))
        i32.const 0x00
        i32.gt_u

        global.set $transport_packet_payload_unit_start_indicator

        ;; adaptation_field_control
        (i32.and
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x03)))
            (i32.const 0x30))

        global.set $transport_packet_adaptation_field_control
    )


    ;; ----------------------------------------------------
    ;; adaptation field
    ;; ----------------------------------------------------

    (func $adaptation_field (param $offset i32)
        (global.set
            $adaptation_field_length
            (i32.load8_u
                (local.get $offset)))
    )

    (func $adaptation_field_get_skip_offset (result i32)
        global.get $transport_packet_adaptation_field_control
        i32.const 0x10
        i32.gt_u

        (if
            (then
                (return
                    (i32.add
                        (i32.const 0x01)
                        (global.get $adaptation_field_length)))
            )
        )

        i32.const 0x00
    )


    ;; ----------------------------------------------------
    ;; pat (program association table)
    ;; ----------------------------------------------------

    (func $pat (param $offset i32)
        ;; pointer_field
        global.get $transport_packet_payload_unit_start_indicator

        (if
            (then
                (local.set
                    $offset
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x01)))
            )
        )

        ;; table_id
        ;; support "program_association_section" only
        (i32.load8_u
            (local.get $offset))
        i32.const 0x00
        i32.ne

        (if
            (then
                return
            )
        )

        ;; program_number
        ;; support "program_map_PID" only
        (i32.add
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x08)))
            
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x09))))
        i32.const 0x00
        i32.eq

        (if
            (then
                return
            )
        )

        ;; program_map_PID
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x0A)))
                    (i32.const 0x1F))
                (i32.const 0x08))
            
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x0B))))

        global.set $pat_program_map_pid
    )


    ;; ----------------------------------------------------
    ;; pmt (program map table)
    ;; ----------------------------------------------------

    (func $pmt (param $offset i32)
        (local $pmt_section_length i32)
        (local $stream_type i32)
        (local $elementary_pid i32)

        ;; pointer_field
        global.get $transport_packet_payload_unit_start_indicator

        (if
            (then
                (local.set
                    $offset
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x01)))
            )
        )

        ;; section_length
        (i32.add
            ;; 3 first bytes of the section - 4 bytes of CRC_32 from the end of the section
            (i32.sub
                (i32.or
                    (i32.shl
                        (i32.and
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x01)))
                            (i32.const 0x03))
                        (i32.const 0x08))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x02))))

                (i32.const 0x01))

            (local.get $offset))

        local.set $pmt_section_length

        ;; program_info_length
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x0A)))
                    (i32.const 0x03))
                (i32.const 0x08))

            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x0B))))

        ;; increase local offset ("program_info_length" value + 12 bytes of the section)
        (i32.add
            (local.get $offset)
            (i32.const 0x0C))
        i32.add

        local.set $offset

        ;; "stream_type" .. "ES_info_length"
        (loop $pmt_loop
            ;; stream_type
            (i32.load8_u
                (local.get $offset))

            local.set $stream_type

            ;; elementary_PID
            (i32.or
                (i32.shl
                    (i32.and
                        (i32.load8_u
                            (i32.add
                                (local.get $offset)
                                (i32.const 0x01)))
                        (i32.const 0x1F))
                    (i32.const 0x08))

                (i32.load8_u
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x02))))

            local.set $elementary_pid

            ;; program mappings

            ;; ISO/IEC 13818-7 Audio with ADTS transport syntax
            (i32.eq
                (local.get $stream_type)
                (i32.const 0x0F))

            (if
                (then
                    (global.set
                        $pmt_elementary_pid_audio
                        (local.get $elementary_pid))
                )
            )

            ;; AVC video stream as defined in ITU-T Rec. H.264 | ISO/IEC 14496-10 Video
            (i32.eq
                (local.get $stream_type)
                (i32.const 0x1B))

            (if
                (then
                    (global.set
                        $pmt_elementary_pid_video
                        (local.get $elementary_pid))
                )
            )

            ;; loop continuation
            ;; skip first 5 bytes of a description + "ES_info_length" size
            (i32.add
                (i32.or
                    (i32.shl
                        (i32.and
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x03)))
                            (i32.const 0x0F))
                        (i32.const 0x08))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x04))))

                (i32.add
                    (local.get $offset)
                    (i32.const 0x05)))

            local.tee $offset
            local.get $pmt_section_length
            i32.lt_u

            (if
                (then
                    br $pmt_loop
                )
            )
        )
    )


    ;; ----------------------------------------------------
    ;; pes
    ;; ----------------------------------------------------

    (func $pes (param $offset i32)
        (local $offset_with_header_data_length i32)
        (local $pes_data_length i32)
        (local $tmp_swap i32)

        ;; prefix checking
        (global.get $transport_packet_payload_unit_start_indicator)
        
        (if
            (then
                ;; packet_start_code_prefix
                (i32.or
                    (i32.or
                        (i32.shl
                            (i32.load8_u
                                (local.get $offset))
                            (i32.const 0x10))
                        
                        (i32.shl
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x01)))
                            (i32.const 0x08)))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x02)))
                )
                i32.const 0x01
                i32.ne

                (if
                    (then
                        (return)   
                    )
                )
            )
        )

        ;; calculate pes data length
        (i32.sub
            (i32.add
                (global.get $memory_cursor)
                (global.get $transport_packet_size))
            (local.get $offset))

        (local.set $pes_data_length)

        ;; PES_header_data_length
        ;; first 9 bytes of the section + "PES_header_data_length" value
        (i32.add
            (i32.const 0x09)
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x08))))

        (local.set $offset)

        ;; record elementary streams

        ;; video
        (i32.eq
            (global.get $transport_packet_pid)
            (global.get $pmt_elementary_pid_video))

        (if
            (then
                global.get $memory_es_video_length
                local.set $tmp_swap

                (global.set
                    $memory_es_video_length
                    (i32.add
                        (global.get $memory_es_video_length)
                        (local.get $pes_data_length)))
                
                (memory.copy
                    (i32.add
                        (global.get $memory_es_video_offset)
                        (local.get $tmp_swap))
                    (local.get $offset)
                    (local.get $pes_data_length))

                (return)
            )
        )

        ;; audio
        (i32.eq
            (global.get $transport_packet_pid)
            (global.get $pmt_elementary_pid_audio))

        (if
            (then
                global.get $memory_es_audio_length
                local.set $tmp_swap

                (global.set
                    $memory_es_audio_length
                    (i32.add
                        (global.get $memory_es_audio_length)
                        (local.get $pes_data_length)))

                (memory.copy
                    (i32.add
                        (global.get $memory_es_audio_offset)
                        (local.get $tmp_swap))
                    (local.get $offset)
                    (local.get $pes_data_length))

                (return)
            )
        )
    )


    ;; ----------------------------------------------------
    ;; utils
    ;; ----------------------------------------------------

    (func $memory_cursor_offset_increase_by (param $value i32)
        (global.set
            $memory_cursor_offset
            (i32.add
                (global.get $memory_cursor_offset)
                (local.get $value)))
    )


    ;; ----------------------------------------------------
    ;; module initialization
    ;; ----------------------------------------------------

    (func $main
        ;;
    )

    (start $main)
)