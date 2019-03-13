<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:si="urn:yourfritz-de:signimage" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text" encoding="UTF-8" />
  <xsl:param name="for" />
  <xsl:template match="/">
    <xsl:for-each select="si:database/si:devices">
      <xsl:apply-templates select="si:device" />
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="si:device"><xsl:if test="contains(@name,$for)"><xsl:apply-templates select="si:key" /></xsl:if></xsl:template>
  <xsl:template match="si:key">DESC="vendor's key from firmware" SRC="<xsl:value-of select="../@name" /> / <xsl:value-of select="@original_name" />" MOD=<xsl:value-of select="si:modulus" /> EXP=<xsl:value-of select="si:exponent" /><xsl:text>&#xa;</xsl:text></xsl:template>
</xsl:stylesheet> 
