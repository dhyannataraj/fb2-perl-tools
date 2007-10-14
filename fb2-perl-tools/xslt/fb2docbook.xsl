<?xml version="1.0" encoding="UTF-8"?>
<!-- 
    
    Copyright 2007 by KiR Jakobson ( http://kir666.ru/fb2docbook/ )
    
    This library is free software; you can redistribute it and/or modify
    it under the terms of the General Public License (GPL).  For
    more information, see http://www.fsf.org/licenses/gpl.txt
    
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0"
    xmlns:exsl="http://exslt.org/common" xmlns:redirect="http://xml.apache.org/xalan/redirect"
    extension-element-prefixes="exsl redirect" exclude-result-prefixes="fb exsl redirect xlink"
    version="1.1">
    <xsl:import href="params/system_params.xsl"/>
    <xsl:import href="l10n/gentext.xsl"/>
    <xsl:import href="fb2docbook_gen_infos.xsl"/>
    <xsl:param name="conv_info_idx"/>
    <xsl:param name="document-element"/>
    <xsl:output encoding="UTF-8" indent="yes" method="xml"
        doctype-system="http://www.docbook.org/xml/4.4/docbookx.dtd"
        doctype-public="-//OASIS//DTD DocBook XML V4.4//EN"/>
    <xsl:key name="note-link" match="fb:section" use="@id"/>
    <xsl:key name="binary-link" match="fb:binary" use="@id"/>
    <xsl:template name="gen_binary_asciiname">
        <xsl:param name="bin_href"/>
        <xsl:value-of select="concat($bin_href, '.base64')"/>
    </xsl:template>
    <xsl:template name="gen_fname">
        <xsl:param name="href"/>
        <xsl:choose>
            <xsl:when test="starts-with($href,'#')">
                <xsl:value-of select="substring-after($href,'#')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$href"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="get_docbook_format">
        <xsl:param name="content-type"/>
        <xsl:value-of
            select="exsl:node-set($fb2.mime-types)/mime-type[@id=$content-type]/@docbook-format"/>
    </xsl:template>
    <xsl:template name="get_part_name">
        <xsl:param name="level"/>
        <xsl:variable name="num_levels" select="count(exsl:node-set($fb2.book-parts)/part)"/>
        <xsl:choose>
            <xsl:when test="$level &gt; 0 and $level &lt; $num_levels">
                <xsl:value-of
                    select="exsl:node-set($fb2.book-parts)/part[@level=string($level)]/@name"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="exsl:node-set($fb2.book-parts)/part[last()]/@name"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="get_part_intro_name">
        <xsl:param name="level"/>
        <xsl:variable name="num_levels" select="count(exsl:node-set($fb2.book-parts)/part)"/>
        <xsl:choose>
            <xsl:when test="$level &gt; 0 and $level &lt; $num_levels">
                <xsl:value-of
                    select="exsl:node-set($fb2.book-parts)/part[@level=string($level)]/@intro-name"
                />
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="exsl:node-set($fb2.book-parts)/part[last()]/@intro-name"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:FictionBook">
        <xsl:variable name="blang">
            <xsl:choose>
                <xsl:when test="fb:description/fb:title-info/fb:lang/text() != ''">
                    <xsl:value-of select="fb:description/fb:title-info/fb:lang/text()"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$fb2.default.language"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <book xml:lang="{$blang}">
            <xsl:for-each select="fb:description">
                <xsl:call-template name="bookinfo"/>
            </xsl:for-each>
            <xsl:apply-templates select="fb:body[not (@name = 'notes' or @name = 'footnotes')]"/>

            <xsl:if test="$fb2.print.infos">
                <xsl:call-template name="title-info-appendix"/>
                <xsl:call-template name="src-title-info-appendix"/>
                <xsl:call-template name="document-info-appendix"/>
                <xsl:call-template name="publish-info-appendix"/>
                <xsl:call-template name="custom-info-appendix"/>
                <xsl:call-template name="technical-appendix"/>
            </xsl:if>

            <xsl:call-template name="binaries_index">
                <xsl:with-param name="idx_fname">
                    <xsl:value-of select="$conv_info_idx"/>
                </xsl:with-param>
            </xsl:call-template>
            <xsl:apply-templates select="fb:binary"/>
            <!--xsl:apply-templates select="fb:body[(@name = 'notes')]"/-->
        </book>
    </xsl:template>
    <xsl:template name="bookinfo">
        <bookinfo>
            <xsl:if test="count(fb:title-info/fb:coverpage|fb:title-info/fb:annotation)">
                <abstract id="preface_annotation" xml:lang="{fb:title-info/fb:lang/text()}">
                    <para>
                        <xsl:apply-templates select="fb:title-info/fb:coverpage/fb:image"/>
                    </para>
                    <xsl:for-each select="fb:title-info/fb:annotation/*">
                        <xsl:choose>
                            <xsl:when
                                test="local-name(.) = 'cite' or local-name(.) = 'empty-line' or local-name(.) = 'table'">
                                <para>
                                    <xsl:apply-templates select="."/>
                                </para>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:apply-templates select="."/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </abstract>
            </xsl:if>
            <xsl:if test="count(fb:src-title-info/fb:coverpage|fb:src-title-info/fb:annotation)">
                <abstract id="preface_annotation_original"
                    xml:lang="{fb:src-title-info/fb:lang/text()}">
                    <para>
                        <xsl:apply-templates select="fb:src-title-info/fb:coverpage/fb:image"/>
                    </para>
                    <xsl:for-each select="fb:src-title-info/fb:annotation/*">
                        <xsl:choose>
                            <xsl:when
                                test="local-name(.) = 'cite' or local-name(.) = 'empty-line' or local-name(.) = 'table'">
                                <para>
                                    <xsl:apply-templates select="."/>
                                </para>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:apply-templates select="."/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                    <!--xsl:apply-templates select="fb:src-title-info/fb:annotation/*"/-->
                </abstract>
            </xsl:if>
            <title>
                <xsl:value-of select="fb:title-info/fb:book-title"/>
            </title>
            <xsl:choose>
                <xsl:when test="count(fb:title-info/fb:author) &gt; 1">
                    <authorgroup>
                        <xsl:apply-templates select="fb:title-info/fb:author" mode="bookinfo"/>
                    </authorgroup>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="fb:title-info/fb:author" mode="bookinfo"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:apply-templates select="fb:title-info/fb:translator" mode="bookinfo"/>
            <xsl:call-template name="bookinfo-sequence"/>
            <xsl:call-template name="bookinfo-date"/>
            <xsl:call-template name="bookinfo-publish"/>
        </bookinfo>
    </xsl:template>
    <xsl:template name="bookinfo-publish">
        <xsl:if test="count(fb:publish-info/fb:publisher)">
            <publishername>
                <xsl:value-of select="fb:publish-info/fb:publisher/text()"/>
            </publishername>
        </xsl:if>
        <xsl:if test="count(fb:publish-info/fb:isbn)">
            <bibliosource class="isbn">
                <xsl:value-of select="fb:publish-info/fb:isbn/text()"/>
            </bibliosource>
        </xsl:if>
        <xsl:if test="count(fb:publish-info/fb:year)">
            <pubdate>
                <xsl:value-of select="fb:publish-info/fb:year/text()"/>
            </pubdate>
        </xsl:if>
    </xsl:template>
    <xsl:template name="bookinfo-date">
        <date>
            <xsl:choose>
                <xsl:when test="fb:title-info/fb:date/text() = ''">
                    <xsl:value-of select="fb:title-info/fb:date/@value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="fb:title-info/fb:date/text()"/>
                </xsl:otherwise>
            </xsl:choose>
        </date>
    </xsl:template>
    <xsl:template name="bookinfo-sequence">
        <xsl:if test="count(fb:title-info/fb:sequence)">
            <seriesvolnums>
                <xsl:value-of select="fb:title-info/fb:sequence/@name"/>
            </seriesvolnums>
            <volumenum>
                <xsl:value-of select="fb:title-info/fb:sequence/@number"/>
            </volumenum>
        </xsl:if>
    </xsl:template>
    <xsl:template match="fb:body">
        <xsl:apply-templates select="@xml:lang|@id"/>
        <xsl:if test="count(fb:image) or count(fb:epigraph)">
            <preface id="{concat('preface_preface', generate-id())}">
                <title id="{concat('prefacetitle', generate-id())}">
                    <xsl:call-template name="gentext.param">
                        <xsl:with-param name="param" select="'Preface'"/>
                    </xsl:call-template>
                </title>
                <xsl:apply-templates select="fb:image"/>
                <xsl:apply-templates select="fb:epigraph"/>
            </preface>
        </xsl:if>
        <xsl:for-each select="fb:section">
            <xsl:call-template name="fb-section">
                <xsl:with-param name="level" select="1"/>
            </xsl:call-template>
        </xsl:for-each>
    </xsl:template>
    <xsl:template name="fb-section">
        <xsl:param name="level"/>
        <xsl:variable name="part-name">
            <xsl:call-template name="get_part_name">
                <xsl:with-param name="level" select="$level"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="part-intro-name">
            <xsl:call-template name="get_part_intro_name">
                <xsl:with-param name="level" select="$level"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:element name="{$part-name}">
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:call-template name="section_title"/>
            <xsl:choose>
                <!-- если нет section в part, не загонять все в partintro; пустой partintro !!! -->
                <xsl:when test="$part-intro-name != ''">
                    <xsl:element name="{$part-intro-name}">
                        <xsl:apply-templates
                            select="*[local-name(.) != 'section' and local-name(.) != 'title']"/>
                    </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates
                        select="*[local-name(.) != 'section' and local-name(.) != 'title']"/>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:for-each select="fb:section">
                <xsl:call-template name="fb-section">
                    <xsl:with-param name="level" select="$level + 1"/>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:element>
    </xsl:template>
    <xsl:template name="section_title">
        <xsl:param name="role" select="''"/>
        <title>
            <xsl:if test="$role != ''">
                <xsl:attribute name="role">
                    <xsl:value-of select="$role"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:for-each select="fb:title/fb:p">
                <xsl:apply-templates/>
                <xsl:text xml:space="preserve"> </xsl:text>
            </xsl:for-each>
        </title>
    </xsl:template>
    <xsl:template match="fb:p">
        <para>
            <xsl:if test="local-name(..) = 'section'">
                <xsl:attribute name="role">p</xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:apply-templates/>
        </para>
    </xsl:template>
    <xsl:template match="fb:p" mode="epigraph">
        <para role="epigraph">
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:apply-templates/>
        </para>
    </xsl:template>
    <!--xsl:template match="fb:epigraph">
        <xsl:element name="epigraph">
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:if test="count(fb:text-author) != 0">
                <attribution>
                    <xsl:apply-templates select="fb:text-author"/>
                </attribution>
            </xsl:if>
            <xsl:apply-templates select="fb:p|fb:poem|fb:cite|fb:empty-line" mode="epigraph"/>
        </xsl:element>
        </xsl:template-->
    <xsl:template match="fb:epigraph">
        <xsl:element name="blockquote">
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:if test="count(fb:text-author) != 0">
                <attribution>
                    <xsl:apply-templates select="fb:text-author"/>
                </attribution>
            </xsl:if>
            <xsl:apply-templates select="*[local-name(.) != 'text-author']"/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="fb:empty-line" name="empty-line">
        <literallayout/>
    </xsl:template>
    <xsl:template match="fb:empty-line" mode="epigraph">
        <xsl:call-template name="empty-line"/>
    </xsl:template>
    <xsl:template match="fb:a">
        <xsl:variable name="href_id">
            <xsl:call-template name="gen_fname">
                <xsl:with-param name="href" select="@xlink:href"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="@type = 'note'">
                <xsl:call-template name="a_footnote">
                    <xsl:with-param name="href_id" select="$href_id"/>
                    <xsl:with-param name="label" select="text()"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="starts-with($href_id,'#')">
                <xsl:call-template name="a_xref">
                    <xsl:with-param name="href_id" select="$href_id"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="a_ulink">
                    <xsl:with-param name="href_id" select="$href_id"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="a_footnote">
        <xsl:param name="href_id"/>
        <xsl:param name="label"/>
        <xsl:element name="footnote">
            <xsl:attribute name="id">
                <xsl:value-of select="$href_id"/>
            </xsl:attribute>
            <xsl:for-each select="key('note-link', $href_id)">
                <!-- == work for XEP, in FOP only work labels without spaces == -->
                <!--xsl:attribute name="label">
                    <xsl:choose>
                        <xsl:when test="$label = ''">
                            <xsl:value-of select="fb:title/fb:p/text()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$label"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:attribute-->
                <xsl:apply-templates select="fb:p"/>
            </xsl:for-each>
            <xsl:if test="count(key('note-link', $href_id)) = 0">
                <xsl:message> Footnote body not found <xsl:value-of select="$href_id"/>!</xsl:message>
                <para>
                    <xsl:call-template name="gentext.param">
                        <xsl:with-param name="param" select="'error.bad.note'"/>
                    </xsl:call-template>
                    <xsl:value-of select="$href_id"/>
                    <xsl:text>!</xsl:text>
                </para>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    <xsl:template name="a_ulink">
        <xsl:param name="href_id"/>
        <ulink url="{$href_id}">
            <xsl:if test="@xlink:type != ''">
                <xsl:attribute name="xlink:type">
                    <xsl:value-of select="@xlink:type"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </ulink>
    </xsl:template>
    <xsl:template name="a_xref">
        <xsl:param name="href_id"/>
        <xref linkend="{$href_id}"/>
    </xsl:template>
    <xsl:template name="metadata_author">
        <xsl:choose>
            <xsl:when test="count(fb:nickname) and count(fb:first-name) = 0">
                <xsl:value-of select="fb:nickname"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="fb:first-name"/>
                <xsl:if test="count(fb:middle-name)">
                    <xsl:text> </xsl:text>
                    <xsl:value-of select="fb:middle-name"/>
                </xsl:if>
                <xsl:text> </xsl:text>
                <xsl:value-of select="fb:last-name"/>
                <xsl:if test="count(fb:nickname)">
                    <xsl:text> &quot;</xsl:text>
                    <xsl:value-of select="fb:nickname"/>
                    <xsl:text>&quot;</xsl:text>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="write_binaries_tree">
        <conversion_info>
            <page>
                <dpi>
                    <width>
                        <xsl:value-of select="$output.dpi.width"/>
                    </width>
                    <height>
                        <xsl:value-of select="$output.dpi.height"/>
                    </height>
                </dpi>
                <size>
                    <width>
                        <xsl:value-of select="$page.width"/>
                    </width>
                    <height>
                        <xsl:value-of select="$page.height"/>
                    </height>
                </size>
                <max_image_margin>
                    <width>
                        <xsl:value-of select="$output.max_image_margin.width"/>
                    </width>
                    <height>
                        <xsl:value-of select="$output.max_image_margin.height"/>
                    </height>
                </max_image_margin>
                <images_mode>
                    <resize>
                        <xsl:value-of select="$output.images_mode.resize"/>
                    </resize>
                    <mode>
                        <xsl:value-of select="$output.images_mode.mode"/>
                    </mode>
                </images_mode>
            </page>
            <metadata>
                <Title>
                    <xsl:value-of
                        select="/fb:FictionBook/fb:description/fb:title-info/fb:book-title"/>
                </Title>
                <Author>
                    <xsl:for-each
                        select="/fb:FictionBook/fb:description/fb:title-info/fb:author[position() = 1]">
                        <xsl:call-template name="metadata_author"/>
                    </xsl:for-each>
                    <xsl:for-each
                        select="/fb:FictionBook/fb:description/fb:title-info/fb:author[position() > 1]">
                        <xsl:text>; </xsl:text>
                        <xsl:call-template name="metadata_author"/>
                    </xsl:for-each>
                </Author>
            </metadata>
            <binaries>
                <xsl:for-each select="fb:binary">
                    <xsl:variable name="bin_ascii_name">
                        <xsl:call-template name="gen_binary_asciiname">
                            <xsl:with-param name="bin_href" select="@id"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <binary href_binary="{@id}" href_ascii="{$bin_ascii_name}"
                        content-type="{@content-type}"/>
                </xsl:for-each>
            </binaries>
        </conversion_info>
    </xsl:template>
    <xsl:template name="binaries_index">
        <xsl:param name="idx_fname"/>
        <xsl:choose>
            <xsl:when test="$document-element = 'exsl:document'">
                <exsl:document href="{$idx_fname}" method="xml" encoding="UTF-8">
                    <xsl:call-template name="write_binaries_tree"/>
                </exsl:document>
            </xsl:when>
            <xsl:when test="$document-element = 'xsl:document'">
                <xsl:document href="{$idx_fname}" method="xml" encoding="UTF-8">
                    <xsl:call-template name="write_binaries_tree"/>
                </xsl:document>
            </xsl:when>
            <xsl:when test="$document-element = 'redirect:write'">
                <redirect:write file="{$idx_fname}">
                    <xsl:call-template name="write_binaries_tree"/>
                </redirect:write>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message> Unknown xsl:document element!!! </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:binary">
        <xsl:variable name="bin_ascii_name">
            <xsl:call-template name="gen_binary_asciiname">
                <xsl:with-param name="bin_href" select="@id"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$document-element = 'exsl:document'">
                <exsl:document href="{$bin_ascii_name}" method="text" indent="no">
                    <xsl:value-of select="text()"/>
                </exsl:document>
            </xsl:when>
            <xsl:when test="$document-element = 'xsl:document'">
                <xsl:document href="{$bin_ascii_name}" method="text" indent="no">
                    <xsl:value-of select="text()"/>
                </xsl:document>
            </xsl:when>
            <xsl:when test="$document-element = 'redirect:write'">
                <redirect:write file="{$bin_ascii_name}">
                    <xsl:value-of select="text()"/>
                </redirect:write>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message> Unknown xsl:document element!!! </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:image">
        <xsl:variable name="href_id">
            <xsl:call-template name="gen_fname">
                <xsl:with-param name="href" select="@xlink:href"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="content-type" select="key('binary-link', $href_id)/@content-type"/>
        <xsl:variable name="docbook-format">
            <xsl:call-template name="get_docbook_format">
                <xsl:with-param name="content-type" select="$content-type"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="media_element">
            <xsl:choose>
                <xsl:when
                    test="local-name(..) = 'section' or local-name(..) = 'body' or local-name(..) = 'coverpage'"
                    >mediaobject</xsl:when>
                <xsl:otherwise>inlinemediaobject</xsl:otherwise>
            </xsl:choose>

        </xsl:variable>
        <xsl:element name="{$media_element}">
            <xsl:apply-templates select="@xml:lang|@id"/>
            <imageobject>
                <imagedata align="{$fb2.image.align}" valign="{$fb2.image.valign}"
                    fileref="{$href_id}" format="{$docbook-format}"/>
            </imageobject>
            <xsl:if test="@alt != ''">
                <textobject>
                    <xsl:value-of select="@alt"/>
                </textobject>
            </xsl:if>
            <xsl:if test="@title != ''">
                <caption>
                    <para>
                        <xsl:value-of select="@title"/>
                    </para>
                </caption>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    <xsl:template match="fb:emphasis">
        <emphasis>
            <xsl:apply-templates/>
        </emphasis>
    </xsl:template>
    <xsl:template match="fb:strong">
        <emphasis role="strong">
            <xsl:apply-templates/>
        </emphasis>
    </xsl:template>
    <xsl:template match="fb:strikethrough">
        <emphasis role="strikethrough">
            <xsl:apply-templates/>
        </emphasis>
    </xsl:template>
    <xsl:template match="fb:sub">
        <subscript>
            <xsl:apply-templates/>
        </subscript>
    </xsl:template>
    <xsl:template match="fb:sup">
        <superscript>
            <xsl:apply-templates/>
        </superscript>
    </xsl:template>
    <xsl:template match="fb:code">
        <code>
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:apply-templates/>
        </code>
    </xsl:template>
    <xsl:template match="fb:cite" name="cite">
        <blockquote>
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:if test="count(fb:text-author) != 0">
                <attribution>
                    <xsl:apply-templates select="fb:text-author"/>
                </attribution>
            </xsl:if>
            <xsl:apply-templates select="*[local-name(.) != 'text-author']"/>
        </blockquote>
    </xsl:template>
    <xsl:template match="fb:cite" mode="epigraph">
        <xsl:call-template name="cite"/>
    </xsl:template>
    <xsl:template match="fb:text-author">
        <author>
            <personname>
                <othername>
                    <xsl:value-of select="text()"/>
                </othername>
            </personname>
        </author>
    </xsl:template>
    <xsl:template match="fb:poem" mode="epigraph">
        <xsl:call-template name="poem"/>
    </xsl:template>
    <xsl:template match="fb:poem" name="poem">
        <xsl:choose>
            <xsl:when test="count(fb:title) &gt; 0">
                <formalpara role="poem">
                    <xsl:apply-templates select="@xml:lang|@id"/>
                    <xsl:call-template name="section_title">
                        <xsl:with-param name="role" select="'poem'"/>
                    </xsl:call-template>
                    <xsl:apply-templates select="fb:epigraph"/>
                    <para role="poem">
                        <xsl:apply-templates select="fb:stanza"/>
                        <xsl:apply-templates select="fb:text-author"/>
                        <xsl:apply-templates select="fb:date"/>
                    </para>
                </formalpara>
            </xsl:when>
            <xsl:otherwise>
                <para role="poem">
                    <xsl:apply-templates select="@xml:lang|@id"/>
                    <xsl:apply-templates select="fb:epigraph"/>
                    <xsl:apply-templates select="fb:stanza"/>
                    <xsl:apply-templates select="fb:text-author"/>
                    <xsl:apply-templates select="fb:date"/>
                </para>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:stanza">
        <xsl:choose>
            <xsl:when test="count(fb:title) &gt; 0">
                <formalpara role="poem">
                    <xsl:call-template name="section_title"/>
                    <para role="poem">
                        <xsl:apply-templates select="@xml:lang|@id"/>
                        <literallayout xml:space="preserve" role="poem">
                            <xsl:apply-templates select="fb:v"/>                            
                        </literallayout>
                    </para>
                </formalpara>
            </xsl:when>
            <xsl:otherwise>
                <literallayout xml:space="preserve" role="poem"><xsl:apply-templates select="@xml:lang|@id"/><xsl:apply-templates select="fb:v"/></literallayout>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:v">
        <xsl:choose>
            <xsl:when test="local-name(..) = 'stanza'">
                <xsl:apply-templates/>
                <xsl:text xml:space="preserve">&#xA;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>
                    <xsl:text>Bad parent of tag v (must be stanza)!!!</xsl:text>
                </xsl:message>
                <simpara>
                    <literal>
                        <xsl:apply-templates/>
                        <xsl:text xml:space="preserve">&#xA;</xsl:text>
                    </literal>
                </simpara>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="fb:table">
        <informaltable>
            <xsl:apply-templates/>
        </informaltable>
    </xsl:template>
    <xsl:template match="fb:tr|fb:th|fb:td">
        <xsl:element name="{local-name(.)}">
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="fb:subtitle">
        <bridgehead>
            <xsl:apply-templates select="@xml:lang|@id"/>
            <xsl:apply-templates/>
        </bridgehead>
    </xsl:template>
    <xsl:template match="fb:style">
        <xsl:comment> == style <xsl:value-of select="@name"/> == </xsl:comment>
        <xsl:choose>
            <xsl:when test="@xml:lang != ''">
                <foreignphrase>
                    <xsl:apply-templates select="@xml:lang"/>
                    <xsl:apply-templates/>
                </foreignphrase>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates/>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:comment> == style_end <xsl:value-of select="@name"/> == </xsl:comment>
    </xsl:template>
    <xsl:template name="bookinfo-person">
        <xsl:param name="person-element"/>
        <xsl:param name="person-class"/>
        <xsl:element name="{$person-element}">
            <xsl:if test="$person-class != ''">
                <xsl:attribute name="class">
                    <xsl:value-of select="$person-class"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates
                select="*[local-name(.) != 'id' and local-name(.) != 'nickname' and local-name(.) != 'home-page' and local-name(.) != 'email']"
                mode="description"/>
            <xsl:if test="count(fb:first-name) = 0 and count(fb:last-name) = 0">
                <xsl:comment> == Bad author, only nickname! == </xsl:comment>
                <surname>
                    <xsl:value-of select="fb:nickname/text()"/>
                </surname>
            </xsl:if>
            <xsl:call-template name="authorblurb"/>
            <xsl:apply-templates select="fb:email" mode="description"/>
        </xsl:element>
    </xsl:template>
    <xsl:template match="fb:author" mode="bookinfo">
        <xsl:call-template name="bookinfo-person">
            <xsl:with-param name="person-element">author</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    <xsl:template match="fb:translator" mode="bookinfo">
        <xsl:call-template name="bookinfo-person">
            <xsl:with-param name="person-element">othercredit</xsl:with-param>
            <xsl:with-param name="person-class">translator</xsl:with-param>
        </xsl:call-template>
    </xsl:template>
    <xsl:template match="fb:first-name" mode="description">
        <firstname>
            <xsl:value-of select="text()"/>
        </firstname>
    </xsl:template>
    <xsl:template match="fb:last-name" mode="description">
        <surname>
            <xsl:value-of select="text()"/>
        </surname>
    </xsl:template>
    <xsl:template match="fb:middle-name" mode="description">
        <lineage>
            <xsl:value-of select="text()"/>
        </lineage>
    </xsl:template>
    <xsl:template match="fb:email" mode="description">
        <email>
            <xsl:value-of select="text()"/>
        </email>
    </xsl:template>
    <xsl:template name="authorblurb">
        <xsl:if test="count(fb:nickname) or count(fb:home-page)">
            <authorblurb>
                <para>
                    <itemizedlist spacing="compact">
                        <xsl:apply-templates select="fb:nickname|fb:home-page" mode="authorblurb"/>
                    </itemizedlist>
                </para>
            </authorblurb>
        </xsl:if>
    </xsl:template>
    <xsl:template match="fb:nickname" mode="authorblurb">
        <listitem>
            <simpara>
                <xsl:call-template name="gentext.param">
                    <xsl:with-param name="param" select="'Nickname'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
                <xsl:value-of select="text()"/>
            </simpara>
        </listitem>
    </xsl:template>
    <xsl:template match="fb:home-page" mode="authorblurb">
        <listitem>
            <simpara>
                <xsl:call-template name="gentext.param">
                    <xsl:with-param name="param" select="'Сайт'"/>
                </xsl:call-template>
                <xsl:text>: </xsl:text>
                <ulink url="{text()}">
                    <xsl:value-of select="text()"/>
                </ulink>
            </simpara>
        </listitem>
    </xsl:template>

    <xsl:template match="@id">
        <xsl:copy/>
    </xsl:template>
    <xsl:template match="@xml:lang">
        <xsl:copy/>
    </xsl:template>
    <xsl:template match="@*">
        <xsl:copy/>
    </xsl:template>
</xsl:stylesheet>
