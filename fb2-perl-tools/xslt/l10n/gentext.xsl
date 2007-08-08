<?xml version="1.0" encoding="UTF-8"?>
<!--

Copyright 2007 by KiR Jakobson ( http://kir666.ru/fb2docbook/ )

This library is free software; you can redistribute it and/or modify
it under the terms of the General Public License (GPL).  For
more information, see http://www.fsf.org/licenses/gpl.txt

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0">
    <xsl:param name="l10n.xml" select="document('l10n.xml')"/>
    <xsl:variable name="l10n.default.language">
        <xsl:value-of select="$fb2.default.language"/>
    </xsl:variable>

    <xsl:template name="gentext.info.title">
        <xsl:param name="context" select="local-name(.)"/>
        <xsl:param name="lang">
            <xsl:call-template name="l10n.info.language"/>
        </xsl:param>
        <xsl:variable name="localization.node" select="($l10n.xml/i18n/l10n[@language=$lang])[1]"/>
        <xsl:if test="count($localization.node) = 0">
            <xsl:message>
                <xsl:text>No "</xsl:text>
                <xsl:value-of select="$lang"/>
                <xsl:text>" localization exists.</xsl:text>
            </xsl:message>
        </xsl:if>
        <xsl:value-of select="$localization.node/context[@name = $context]/title/@text"/>
    </xsl:template>

    <xsl:template name="gentext.info.param">
        <xsl:param name="context" select="local-name(..)"/>
        <xsl:param name="param" select="local-name(.)"/>
        <xsl:param name="lang">
            <xsl:call-template name="l10n.info.language"/>
        </xsl:param>
        <xsl:variable name="localization.node" select="($l10n.xml//i18n/l10n[@language=$lang])[1]"/>
        <xsl:if test="count($localization.node) = 0">
            <xsl:message>
                <xsl:text>No "</xsl:text>
                <xsl:value-of select="$lang"/>
                <xsl:text>" localization exists.</xsl:text>
            </xsl:message>
        </xsl:if>
        <xsl:value-of
            select="$localization.node/context[@name = $context]/param[@name = $param]/@text"/>
    </xsl:template>

    <xsl:template name="gentext.param">
        <xsl:param name="param" select="local-name(.)"/>
        <xsl:param name="lang">
            <xsl:call-template name="l10n.info.language"/>
        </xsl:param>
        <xsl:variable name="localization.node" select="($l10n.xml//i18n/l10n[@language=$lang])[1]"/>
        <xsl:if test="count($localization.node) = 0">
            <xsl:message>
                <xsl:text>No "</xsl:text>
                <xsl:value-of select="$lang"/>
                <xsl:text>" localization exists.</xsl:text>
            </xsl:message>
        </xsl:if>
        <xsl:value-of select="$localization.node/param[@name = $param]/@text"/>
    </xsl:template>

    <xsl:template name="l10n.info.language">
        <xsl:variable name="flang"
            select="/fb:FictionBook/fb:description/fb:title-info/fb:lang/text()"/>
        <xsl:choose>
            <xsl:when test="$l10n.xml/i18n/l10n[@language=$flang]">
                <xsl:value-of select="$flang"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message>
                    <xsl:text>No localization exists for "</xsl:text>
                    <xsl:value-of select="$flang"/>
                    <xsl:text>". Using default "</xsl:text>
                    <xsl:value-of select="$l10n.default.language"/>
                    <xsl:text>".</xsl:text>
                </xsl:message>
                <xsl:value-of select="$l10n.default.language"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
