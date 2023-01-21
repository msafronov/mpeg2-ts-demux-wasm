(module
    ;; ++++++++++++++++++++++++++++++++++++++++++++++++++++
    ;; _main.wat
    ;; ++++++++++++++++++++++++++++++++++++++++++++++++++++

    (memory (export "memory") 0x00 0xFF)


    ;; ----------------------------------------------------
    ;; globals
    ;; ----------------------------------------------------

    (global $memory_wasm_page_byte_count i32 (i32.const 0x10000))
    (global $memory_cursor (mut i32) (i32.const 0x00))
    (global $memory_cursor_offset (mut i32) (i32.const 0x00))
    (global $memory_segment_offset (export "s_offset") (mut i32) (i32.const 0x00))
    (global $memory_segment_length (export "s_len") (mut i32) (i32.const 0x00))
    (global $memory_metadata_offset (export "m_offset") (mut i32) (i32.const 0x00))
    (global $memory_metadata_current_offset (mut i32) (i32.const 0x00))
    (global $memory_metadata_packet_length (export "m_p_len") i32 (i32.const 0x12))
    (global $memory_metadata_length (export "m_len") (mut i32) (i32.const 0x00))
    (global $memory_es_offset (export "es_offset") (mut i32) (i32.const 0x00))
    (global $memory_es_length (export "es_len") (mut i32) (i32.const 0x00))

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

    ;; 0x00 => "00" Without
    ;; 0x80 => "10" PTS
    ;; 0xC0 => "11" PTS + DTS
    (global $pes_pts_dts_flags (mut i32) (i32.const 0x00))
    (global $pes_pts (mut i32) (i32.const 0x00))
    (global $pes_dts (mut i32) (i32.const 0x00))


    ;; ----------------------------------------------------
    ;; public api
    ;; ----------------------------------------------------

    (func $malloc (export "malloc") (param $segment_buffer_length i32) (result i32)
        (local $memory_blocks_for_segment_buffer i32)
        (local $memory_blocks_for_metadata_buffer i32)

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

        ;; calculate necessary segment memory blocks count
        (local.set
            $memory_blocks_for_segment_buffer
            (i32.trunc_f32_u
                (f32.ceil
                    (f32.div
                        (f32.convert_i32_u
                            (local.get $segment_buffer_length))
                        (f32.convert_i32_u
                            (global.get $memory_wasm_page_byte_count))))))
        
        ;; calculate necessary metadata memory blocks count
        (local.set
            $memory_blocks_for_metadata_buffer
            (i32.trunc_f32_u
                (f32.ceil
                    (f32.div
                        (f32.convert_i32_u
                            (local.get $memory_blocks_for_segment_buffer))
                        (f32.convert_i32_u
                            (i32.const 0x06))))))

        ;; memory allocation (ts + metadata + es blocks)
        (memory.grow
            (i32.sub
                (i32.add
                    (i32.mul
                        (local.get $memory_blocks_for_segment_buffer)
                        (i32.const 0x02))
                    (local.get $memory_blocks_for_metadata_buffer))

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

        ;; metadata offset and length updating
        (global.set $memory_metadata_offset
            (i32.mul
                (local.get $memory_blocks_for_segment_buffer)
                (global.get $memory_wasm_page_byte_count)))

        (global.set $memory_metadata_length
            (i32.const 0x00))

        ;; es offset and length updating
        (global.set $memory_es_offset
            (i32.add
                (global.get $memory_metadata_offset)
                (i32.mul
                    (local.get $memory_blocks_for_metadata_buffer)
                    (global.get $memory_wasm_page_byte_count))))

        (global.set $memory_es_length
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